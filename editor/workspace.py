"""Bounded local workspace transport; no shell, provider clients or Git writes."""
import base64
from contextlib import contextmanager
import fcntl
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import stat
import subprocess
import tempfile
import threading
import time

MAX_FILE = 1024 * 1024
READ_ROOTS = {'src', 'shared', 'tools', 'editor', 'tests', 'data', 'docs', 'prompts', 'scripts', 'assets'}
READ_FILES = {'README.md', 'AGENTS.md'}
READ_EXTS = {'.odin', '.py', '.js', '.css', '.html', '.json', '.md', '.swift', '.sh', '.fountain', '.txt'}
WRITE_EXTS = {'src': {'.odin'}, 'shared': {'.odin'}, 'tools': {'.odin', '.py'},
              'editor': {'.py', '.js', '.css', '.html'}, 'tests': {'.odin', '.py', '.js', '.json', '.swift'}}
COMMANDS = {'check-game': ['check', 'src'], 'check-dev': ['check', 'src', '-define:DEV_TOOLS=true'],
            'build-content': ['build', 'tools/content'], 'build-dev': ['build', 'src', '-define:DEV_TOOLS=true'],
            'build-release': ['build', 'src']}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def now():
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())

class Workspace:
    def __init__(self, bridge, error, reservations=()):
        self.bridge, self.root, self.Error = bridge, bridge.root, error
        self.root_fd = os.open(str(self.root), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        self.reservations = tuple(reservations)
        for item in self.reservations:
            self.parts(item, unrestricted=True)
        self.write_lock = threading.Lock()
        self.jobs_lock = threading.RLock()
        self.jobs = {}
        self.artifacts = {}
        self.latest = {}
        self.threads = []
        self.compiler = shutil.which('odin')
        self.compiler = str(Path(self.compiler).resolve()) if self.compiler else None
        self.git = shutil.which('git')
        self.git = str(Path(self.git).resolve()) if self.git else None
        self.compiler_version = 'unavailable'
        if self.compiler:
            try:
                self.compiler_version = subprocess.run([self.compiler, 'version'], capture_output=True, timeout=5).stdout.decode('utf-8', 'replace').strip()
            except (OSError, subprocess.TimeoutExpired):
                pass

    def parts(self, path, unrestricted=False):
        if (not isinstance(path, str) or not path or len(path) > 1024 or '\\' in path
                or any(ord(c) < 32 or ord(c) == 127 for c in path)):
            raise self.Error(400, 'Unsafe relative path')
        parts = path.split('/')
        if any(not p or p in ('.', '..') or p.startswith('.') for p in parts):
            # Only private bridge code may pass hidden internal roots.
            if not (unrestricted and parts[0] == '.studio' and all(p and p not in ('.', '..') for p in parts)):
                raise self.Error(400, 'Hidden, absolute or non-normalized path rejected')
        if not unrestricted and path not in READ_FILES and (parts[0] not in READ_ROOTS or Path(path).suffix not in READ_EXTS):
            raise self.Error(403, 'File is outside the readable allowlist')
        return parts

    def parent(self, path, internal=False, create=False):
        parts = self.parts(path, unrestricted=internal)
        fd = os.dup(self.root_fd)
        try:
            for component in parts[:-1]:
                if create:
                    try:
                        os.mkdir(component, 0o700, dir_fd=fd)
                    except FileExistsError:
                        pass
                nxt = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
                os.close(fd)
                fd = nxt
            return fd, parts[-1]
        except OSError:
            os.close(fd)
            raise self.Error(403, 'Missing, symlinked or unsafe parent directory')

    def bytes(self, path, internal=False, limit=MAX_FILE):
        parent, name = self.parent(path, internal)
        fd = None
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
                raise self.Error(400, 'Expected a bounded regular file')
            data = b''
            while len(data) <= limit:
                chunk = os.read(fd, min(65536, limit + 1 - len(data)))
                if not chunk:
                    break
                data += chunk
            if len(data) > limit:
                raise self.Error(400, 'File exceeds read limit')
            after = os.fstat(fd)
            if (info.st_size, info.st_mtime_ns, info.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
                raise self.Error(409, 'File changed during read')
            return data, info
        except FileNotFoundError:
            raise self.Error(404, 'File no longer exists')
        except OSError:
            raise self.Error(403, 'Unsafe or unreadable file')
        finally:
            if fd is not None:
                os.close(fd)
            os.close(parent)

    def writable(self, path):
        parts = self.parts(path)
        return (Path(path).suffix in WRITE_EXTS.get(parts[0], set()) and
                not any(path == r or path.startswith(r + '/') for r in self.reservations))

    def read(self, path):
        data, info = self.bytes(path)
        try:
            text = data.decode('utf-8')
        except UnicodeError:
            raise self.Error(400, 'File is not UTF-8')
        return {'path': path, 'text': text, 'sha256': digest(data), 'size': len(data),
                'writable': self.writable(path) and info.st_nlink == 1, 'observed_at': now()}

    def tree(self):
        files = [{'path': name, 'writable': False} for name in sorted(READ_FILES) if (self.root / name).is_file() and not (self.root / name).is_symlink()]
        # os.walk never follows symlinks; read() independently reopens through no-follow descriptors.
        for root in sorted(READ_ROOTS):
            base = self.root / root
            if base.is_symlink() or not base.is_dir():
                continue
            for parent, dirs, names in os.walk(str(base), followlinks=False):
                dirs[:] = sorted(d for d in dirs if not d.startswith('.') and d != '__pycache__' and not (Path(parent) / d).is_symlink())
                for name in sorted(names):
                    path = Path(parent) / name
                    if name.startswith('.') or path.suffix not in READ_EXTS or path.is_symlink() or not path.is_file():
                        continue
                    relative = path.relative_to(self.root).as_posix()
                    files.append({'path': relative, 'writable': self.writable(relative) and path.stat().st_nlink == 1})
                    if len(files) >= 4096:
                        return {'files': files, 'truncated': True, 'reservations': self.reservations}
        return {'files': files, 'truncated': False, 'reservations': self.reservations}

    def parent_unchanged(self, path, fd, internal=False):
        root_info = os.stat(str(self.root), follow_symlinks=False)
        held = os.fstat(self.root_fd)
        if (root_info.st_dev, root_info.st_ino) != (held.st_dev, held.st_ino):
            raise self.Error(409, 'Launch root changed')
        current, _ = self.parent(path, internal=internal)
        try:
            a, b = os.fstat(current), os.fstat(fd)
            if (a.st_dev, a.st_ino) != (b.st_dev, b.st_ino):
                raise self.Error(409, 'Parent directory changed')
        finally:
            os.close(current)

    def journal(self, transaction, value):
        path = '.studio/source-history/' + transaction + '.json'
        parent, name = self.parent(path, internal=True, create=True)
        temp = 'record_' + secrets.token_hex(12)
        fd = None
        try:
            fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent)
            with os.fdopen(fd, 'wb') as stream:
                fd = None
                stream.write(json.dumps(value, ensure_ascii=False).encode())
                stream.flush()
                os.fsync(stream.fileno())
            self.parent_unchanged(path, parent, internal=True)
            os.replace(temp, name, src_dir_fd=parent, dst_dir_fd=parent)
            os.fsync(parent)
        finally:
            if fd is not None:
                os.close(fd)
            try:
                os.unlink(temp, dir_fd=parent)
            except FileNotFoundError:
                pass
            os.close(parent)

    @contextmanager
    def managed_lock(self):
        parent, name = self.parent('.studio/source.lock', internal=True, create=True)
        fd = None
        try:
            fd = os.open(name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=parent)
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
                raise self.Error(403, 'Unsafe source lock')
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise self.Error(409, 'Source writer busy; original buffer/precondition kept')
            current = os.stat(name, dir_fd=parent, follow_symlinks=False)
            if (info.st_dev, info.st_ino) != (current.st_dev, current.st_ino) or current.st_nlink != 1:
                raise self.Error(409, 'Source lock replaced externally')
            yield
        finally:
            if fd is not None:
                os.close(fd)
            os.close(parent)

    def write(self, path, expected, text, request_id):
        if not self.writable(path):
            raise self.Error(403, 'Read-only root, extension or ownership reservation')
        if not isinstance(expected, str) or not re.fullmatch('[a-f0-9]{64}', expected):
            raise self.Error(400, 'Expected exact-byte SHA-256 precondition')
        if not isinstance(text, str) or not isinstance(request_id, str) or not re.fullmatch('[A-Za-z0-9_-]{1,96}', request_id):
            raise self.Error(400, 'Expected text and bounded request ID')
        try:
            data = text.encode('utf-8')
        except UnicodeError:
            raise self.Error(400, 'Invalid UTF-8 text')
        if len(data) > 200000 or '\x00' in text:
            raise self.Error(413, 'Source text exceeds 200000 bytes or contains NUL')
        with self.write_lock, self.managed_lock():
            old, info = self.bytes(path)
            try:
                old.decode('utf-8')
            except UnicodeError:
                raise self.Error(400, 'Existing source is not UTF-8')
            if info.st_nlink != 1:
                raise self.Error(403, 'Hardlinked write target rejected')
            if digest(old) != expected:
                raise self.Error(409, 'Stale source revision; buffer retained, reload explicitly')
            if old == data:
                return {'commit_state': 'no_op', 'sha256': expected, 'path': path, 'request_id': request_id}
            transaction = 'source_' + secrets.token_hex(16)
            record = {'transaction_id': transaction, 'request_id': request_id, 'path': path,
                      'observed_at': now(), 'before_sha256': expected, 'after_sha256': digest(data),
                      'before_base64': base64.b64encode(old).decode(), 'state': 'prepared',
                      'writer': 'managed request (label is not authenticated identity)'}
            parent, name = self.parent(path)
            temp = '.studio-write-' + secrets.token_hex(16)
            renamed = False
            try:
                self.journal(transaction, record)
                fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, stat.S_IMODE(info.st_mode), dir_fd=parent)
                with os.fdopen(fd, 'wb') as stream:
                    os.fchmod(stream.fileno(), stat.S_IMODE(info.st_mode))
                    stream.write(data)
                    stream.flush()
                    os.fsync(stream.fileno())
                self.parent_unchanged(path, parent)
                check, final = self.bytes(path)
                if digest(check) != expected or final.st_nlink != 1 or (info.st_dev, info.st_ino) != (final.st_dev, final.st_ino):
                    raise self.Error(409, 'External source change; replacement cancelled')
                os.replace(temp, name, src_dir_fd=parent, dst_dir_fd=parent)
                renamed = True
                os.fsync(parent)
                record['state'] = 'committed'
                self.journal(transaction, record)
            except (OSError, self.Error) as error:
                if renamed:
                    return {'commit_state': 'committed_durability_uncertain', 'path': path,
                            'sha256': digest(data), 'transaction_id': transaction, 'error': str(error)}
                if isinstance(error, self.Error):
                    raise
                raise self.Error(500, 'Source not replaced; recoverable before-image: ' + transaction + ': ' + str(error))
            finally:
                try:
                    os.unlink(temp, dir_fd=parent)
                except FileNotFoundError:
                    pass
                os.close(parent)
            return {'commit_state': 'committed', 'sha256': digest(data), 'path': path,
                    'transaction_id': transaction, 'request_id': request_id}

    def git_run(self, args):
        if not self.git:
            raise self.Error(503, 'Git unavailable')
        environment = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        environment.update(GIT_OPTIONAL_LOCKS='0', GIT_EXTERNAL_DIFF='', GIT_PAGER='cat', GIT_CONFIG_NOSYSTEM='1')
        return subprocess.run([self.git, '--no-pager', '-c', 'core.fsmonitor=false', '-c', 'core.hooksPath=/dev/null'] + args,
                              cwd=str(self.root), capture_output=True, timeout=10,
                              env=environment)

    def diff(self, path):
        current = self.read(path)
        head = self.git_run(['rev-parse', '--verify', 'HEAD'])
        if head.returncode:
            return {'available': False, 'reason': head.stderr.decode('utf-8', 'replace')}
        # `show HEAD:path` is an exact object lookup, with no textconv or external diff.
        result = self.git_run(['show', 'HEAD:' + path])
        if result.returncode:
            tracked = self.git_run(['ls-tree', '-z', 'HEAD', '--', ':(literal)' + path])
            if tracked.returncode or tracked.stdout:
                return {'available': False, 'reason': result.stderr.decode('utf-8', 'replace')}
            baseline = ''
            added = True
        else:
            baseline, added = result.stdout.decode('utf-8', 'replace'), False
        return {'available': True, 'head': head.stdout.decode().strip(), 'added': added,
                'sha256': current['sha256'], 'diff': ''.join(difflib.unified_diff(baseline.splitlines(True), current['text'].splitlines(True),
                                                           fromfile='HEAD/' + path, tofile='disk/' + path))}

    def search(self, text, limit):
        if not isinstance(text, str) or not 1 <= len(text) <= 256 or type(limit) is not int or not 1 <= limit <= 200:
            raise self.Error(400, 'Literal search requires 1..256 characters and limit 1..200')
        results = []
        for item in self.tree()['files']:
            try:
                source = self.read(item['path'])
            except self.Error:
                continue
            for number, line in enumerate(source['text'].splitlines(), 1):
                column = line.find(text)
                if column >= 0:
                    results.append({'path': item['path'], 'line': number, 'column': column + 1, 'text': line[:1000]})
                    if len(results) == limit:
                        return {'matches': results, 'truncated': True}
        return {'matches': results, 'truncated': False}

    def fingerprint(self, command):
        roots = ('shared/', 'tools/content/') if command == 'build-content' else ('src/', 'shared/')
        hashed = hashlib.sha256()
        # Includes additions/deletions and exact bytes, never mtime alone.
        tree = self.tree()
        if tree['truncated']:
            raise self.Error(400, 'Source tree exceeds fingerprint limit')
        for root in roots:
            base = self.root / root.rstrip('/')
            if base.is_symlink():
                raise self.Error(403, 'Symlinked compiler input root rejected')
            for parent, dirs, names in os.walk(str(base), followlinks=False):
                if any((Path(parent) / name).is_symlink() for name in dirs + [n for n in names if n.endswith('.odin')]):
                    raise self.Error(403, 'Symlinked compiler inputs rejected')
        for item in tree['files']:
            path = item['path']
            if path.startswith(roots) and path.endswith('.odin'):
                data, _ = self.bytes(path)
                hashed.update(path.encode() + b'\0' + bytes.fromhex(digest(data)))
        if self.compiler:
            info = os.stat(self.compiler)
            hashed.update((self.compiler + self.compiler_version + str((info.st_size, info.st_mtime_ns))).encode())
        return hashed.hexdigest()

    def start_job(self, command):
        if not self.compiler:
            raise self.Error(503, 'Odin compiler unavailable')
        with self.jobs_lock:
            if any(j['state'] in ('starting', 'running') for j in self.jobs.values()):
                raise self.Error(409, 'Another compiler job is active; stop it or wait')
            job_id = 'job_' + secrets.token_hex(12)
            parent, name = self.parent('build/studio/jobs/' + job_id + '/artifact', internal=True, create=True)
            os.close(parent)
            output = self.root / 'build/studio/jobs' / job_id / name
            argv = [self.compiler] + COMMANDS[command][:]
            if command.startswith('build-'):
                argv += ['-out:' + str(output)]
            job = {'job_id': job_id, 'command': command, 'state': 'starting', 'argv': argv, 'cwd': str(self.root),
                   'started_at': now(), 'finished_at': None, 'pid': None, 'exit_code': None,
                   'compiler_version': self.compiler_version, 'source_before': self.fingerprint(command),
                   'source_after': None, 'current_source': False, 'artifact': str(output) if command.startswith('build-') else None,
                   '_log': tempfile.TemporaryFile(), '_process': None, '_stopped': False}
            self.jobs[job_id] = job
            self.latest[command] = job_id
            # Invalidate before spawning: failed builds never fall back to a previous artifact.
            self.artifacts.pop(command, None)
            worker = threading.Thread(target=self.run_job, args=(job,), daemon=True)
            self.threads.append(worker)
            worker.start()
            return self.job_status(job_id, 0)

    def run_job(self, job):
        try:
            with self.jobs_lock:
                if job['_stopped']:
                    job.update(state='stopped', finished_at=now())
                    return
                process = subprocess.Popen(job['argv'], cwd=str(self.root), stdin=subprocess.DEVNULL,
                                           stdout=job['_log'], stderr=subprocess.STDOUT, start_new_session=True)
                job['_process'], job['pid'] = process, process.pid
                job['state'] = 'running'
            try:
                code = process.wait(timeout=120)
            except subprocess.TimeoutExpired:
                self.stop_job(job['job_id'])
                code = process.returncode
                job['error'] = 'Compiler timed out after 120 seconds'
            after = self.fingerprint(job['command'])
            with self.jobs_lock:
                job.update(exit_code=code, source_after=after, current_source=after == job['source_before'], finished_at=now(),
                           state='stopped' if job['_stopped'] else 'exited')
                if code == 0 and job['current_source'] and job['artifact'] and not job['_stopped']:
                    data, info = self.bytes(Path(job['artifact']).relative_to(self.root).as_posix(), internal=True, limit=128 * MAX_FILE)
                    if info.st_nlink != 1 or not info.st_mode & 0o111:
                        raise self.Error(500, 'Compiler output is not a private executable')
                    job['artifact_sha256'] = digest(data)
                    self.artifacts[job['command']] = job['job_id']
        except Exception as error:
            with self.jobs_lock:
                process = job['_process']
                job.update(state='failed-to-start' if process is None else ('stopped' if job['_stopped'] else 'exited'),
                           exit_code=process.poll() if process is not None else None, current_source=False, error=str(error), finished_at=now())

    def diagnostics(self, log):
        found = []
        for line in log.splitlines():
            match = re.match(r'(.+?)\((\d+):(\d+)\)\s*(Error|Warning|Syntax Error):\s*(.*)', line)
            if match:
                path, row, column, severity, message = match.groups()
                if path.startswith(str(self.root) + '/'):
                    path = path[len(str(self.root)) + 1:]
                try:
                    self.parts(path)
                except self.Error:
                    continue
                found.append({'path': path, 'line': int(row), 'column': int(column), 'severity': severity, 'message': message})
        return found

    def job_status(self, job_id, cursor):
        if not isinstance(job_id, str) or job_id not in self.jobs or type(cursor) is not int or cursor < 0:
            raise self.Error(400, 'Unknown owned job or invalid log cursor')
        with self.jobs_lock:
            job = self.jobs[job_id]
            size = os.fstat(job['_log'].fileno()).st_size
            start = max(min(cursor, size), size - 65536)
            chunk = os.pread(job['_log'].fileno(), min(65536, size - start), start)
            result = {key: value for key, value in job.items() if not key.startswith('_')}
            result.update(log=chunk.decode('utf-8', 'replace'), cursor=start + len(chunk), truncated=start > cursor,
                          diagnostics=self.diagnostics(os.pread(job['_log'].fileno(), min(size, 65536), max(0, size - 65536)).decode('utf-8', 'replace')))
            return result

    def stop_job(self, job_id):
        if not isinstance(job_id, str) or job_id not in self.jobs:
            raise self.Error(400, 'Unknown owned job')
        with self.jobs_lock:
            job = self.jobs[job_id]
            process = job['_process']
            if job['state'] in ('starting', 'running'):
                job['_stopped'] = True
            if process is not None and process.poll() is None:
                job['_stopped'] = True
                os.killpg(process.pid, signal.SIGTERM)
        if process is not None:
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=3)
        return self.job_status(job_id, 0)

    def artifact_path(self, command):
        with self.jobs_lock:
            job_id = self.artifacts.get(command)
            job = self.jobs.get(job_id)
            if not job or self.latest.get(command) != job_id or job['state'] != 'exited' or job['exit_code'] != 0 or not job['current_source']:
                raise self.Error(409, 'Build successfully before using artifact: ' + command)
            if job['source_before'] != self.fingerprint(command):
                raise self.Error(409, 'Artifact is stale; rebuild saved source: ' + command)
            data, info = self.bytes(Path(job['artifact']).relative_to(self.root).as_posix(), internal=True, limit=128 * MAX_FILE)
            if digest(data) != job.get('artifact_sha256') or info.st_nlink != 1 or not info.st_mode & 0o111:
                raise self.Error(409, 'Artifact changed; rebuild: ' + command)
            return job

    def run_scene(self):
        with self.jobs_lock:
            job = self.artifact_path('build-dev')
            loaded = self.bridge.content('inspect-scene')
            if loaded['exit_code'] != 0:
                raise self.Error(409, 'Saved content is invalid; preview was not launched')
            status = self.bridge.launch_preview(job['artifact'])
            status.update(artifact=job['artifact'], artifact_sha256=job['artifact_sha256'],
                          source_fingerprint=job['source_before'], loaded_content_revision=loaded['result']['graph_revision'])
            return status

    def tasks(self):
        observed = now()
        source = self.read('docs/ORCHESTRATION_LOG.md')
        text = source['text']
        rows = []
        for number, line in enumerate(text.splitlines(), 1):
            if line.startswith('| T-'):
                columns = [x.strip() for x in line.strip('|').split('|')]
                if len(columns) >= 5:
                    status = columns[4]
                    # All lifecycle words are recorded claims, never inferred acceptance.
                    states = [label for label, pattern in [('accepted', r'\baccepted\b|\bACCEPT\b'), ('reviewed', r'\breviewed\b'),
                              ('reported', r'\bdelivered\b|\bdone\b|\bhandoff\b')] if re.search(pattern, status, re.I)]
                    rows.append({'id': columns[0], 'model': columns[1], 'scope': columns[2], 'checkout_base': columns[3],
                                 'recorded_status': status, 'recorded_claims': states, 'provider_state': 'unknown/unavailable',
                                 'source': 'docs/ORCHESTRATION_LOG.md:' + str(number), 'observed_at': observed})
        claims = []
        for number, line in enumerate(text.splitlines(), 1):
            if 'File owners now:' in line or (line.startswith('| T-') and any(x in line for x in ('running', 'E3 web/bridge', 'M4 fixes'))):
                claims.append({'text': line, 'source': 'docs/ORCHESTRATION_LOG.md:' + str(number), 'observed_at': observed})
        status = self.git_run(['status', '--porcelain=v1', '-z', '--untracked-files=normal'])
        history = self.git_run(['log', '-8', '--format=%H%x09%aI%x09%s'])
        observation = {'available': False, 'reason': 'No exported T3 observation; provider activity is unknown/unavailable'}
        try:
            data, _ = self.bytes('build/studio/orchestration.json', internal=True, limit=262144)
            value = json.loads(data.decode('utf-8'))
            if (not isinstance(value, dict) or not isinstance(value.get('observations'), list)
                    or len(value['observations']) > 128):
                raise ValueError('Expected bounded observations array')
            for entry in value['observations']:
                if not isinstance(entry, dict) or not all(isinstance(entry.get(key), str) and entry[key] for key in ('task_id', 'raw_state', 'observed_at', 'evidence_reference')):
                    raise ValueError('Missing task ID, raw state, time or evidence reference')
            observation = {'available': True, 'source': 'build/studio/orchestration.json', 'sha256': digest(data),
                           'label': 'Exported observation, last observed only; not a live lease', 'snapshot': value}
        except (self.Error, ValueError, UnicodeError) as error:
            observation['reason'] += ': ' + str(error)
        changes = status.stdout.decode('utf-8', 'replace').split('\0')
        transactions = []
        directory = self.root / '.studio/source-history'
        if directory.is_dir() and not directory.is_symlink():
            for path in sorted(directory.glob('source_*.json'))[-30:]:
                try:
                    raw, _ = self.bytes('.studio/source-history/' + path.name, internal=True)
                    item = json.loads(raw)
                    transactions.append({k: v for k, v in item.items() if k != 'before_base64'})
                except (self.Error, ValueError):
                    pass
        return {'observed_at': observed, 'orchestration_log': source, 'tasks': rows, 'ownership_claims': claims,
                'ownership_resolution': 'unresolved: historical owner list and newer task scopes coexist' if len(claims) > 1 else 'No exclusive ownership inferred',
                'provider_observation': observation, 'git': {'status_exit_code': status.returncode, 'status_porcelain_z': changes,
                'status_stderr': status.stderr.decode('utf-8', 'replace'), 'log_exit_code': history.returncode, 'log': history.stdout.decode('utf-8', 'replace')},
                'managed_source_transactions': transactions, 'reservations': self.reservations}

    def close(self):
        for job_id in list(self.jobs):
            self.stop_job(job_id)
        for worker in self.threads:
            worker.join(timeout=5)
        for job in self.jobs.values():
            job['_log'].close()
        if self.root_fd is not None:
            os.close(self.root_fd)
            self.root_fd = None
