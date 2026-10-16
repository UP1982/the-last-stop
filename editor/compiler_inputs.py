"""Conservative project-local Odin input discovery, independent of the source UI allowlist."""
import json
import os
from pathlib import Path
import re
import stat


def tokens(source):
    """Read enough Odin syntax to distinguish dependencies from comments/string contents.

    Unsupported path expressions fail closed in references(); this is not an Odin parser.
    Block comments nest, and raw strings and rune literals can contain comment markers.
    """
    i = 0
    while i < len(source):
        if source[i].isspace():
            i += 1
        elif source.startswith('//', i):
            end = source.find('\n', i)
            i = len(source) if end < 0 else end + 1
        elif source.startswith('/*', i):
            depth, i = 1, i + 2
            while depth and i < len(source):
                if source.startswith('/*', i):
                    depth, i = depth + 1, i + 2
                elif source.startswith('*/', i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
        elif source[i] in ('"', "'", '`'):
            quote, start = source[i], i
            i += 1
            while i < len(source):
                if source[i] == quote:
                    i += 1
                    break
                if source[i] == '\\' and quote != '`':
                    i += 1
                i += 1
            literal = source[start:i]
            if quote == '`' and literal.endswith('`'):
                yield ('string', literal[1:-1])
            elif quote == '"':
                try:
                    yield ('string', json.loads(literal))
                except ValueError:
                    yield ('invalid-string', literal)
            else:
                yield ('rune', literal)
        else:
            match = re.match(r'[A-Za-z_][A-Za-z_0-9]*', source[i:])
            word = match.group() if match else source[i]
            yield ('word', word)
            i += len(word)


def references(source):
    items = list(tokens(source))
    for i, token in enumerate(items):
        if token == ('word', 'import'):
            j = i + 1
            if j < len(items) and items[j][0] == 'word' and re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', items[j][1]):
                j += 1  # optional package/library alias
            foreign = i > 0 and items[i - 1] == ('word', 'foreign')
            if foreign and j < len(items) and items[j] == ('word', '{'):
                j += 1
                while j < len(items) and items[j] != ('word', '}'):
                    if items[j] == ('word', ','):
                        j += 1
                        continue
                    if items[j][0] != 'string':
                        raise ValueError('foreign import requires literal library paths')
                    yield ('foreign', items[j][1])
                    j += 1
                if j == len(items):
                    raise ValueError('unterminated foreign import')
            elif j < len(items) and items[j][0] == 'string':
                yield ('foreign' if foreign else 'import', items[j][1])
            else:
                raise ValueError('import requires a literal package path')
        elif token == ('word', '#') and i + 1 < len(items) and items[i + 1][1] in ('load', 'load_directory', 'load_hash'):
            if (i + 4 >= len(items) or items[i + 2] != ('word', '(')
                    or items[i + 3][0] != 'string' or items[i + 4][1] not in (')', ',')):
                raise ValueError('#load/#load_directory/#load_hash requires a literal project-local path')
            yield (items[i + 1][1], items[i + 3][1])


def collect(workspace):
    """Hash all regular files in broad roots plus recursively discovered local inputs.

    No UI extension/hidden-file filtering: binary, hidden and compile-time inputs count.
    Symlinks/nonregular entries are refused rather than silently omitted. Compiler-owned
    core/vendor/base collections and system linker names belong to the pinned toolchain.
    """
    inputs, pending, scanned = {}, [], set()
    total = 0

    def add(path, optional=False):
        nonlocal total
        if path in inputs:
            return
        try:
            # Descriptor-relative traversal also works for hidden dependency entries.
            parts = path.split('/')
            fd = os.dup(workspace.root_fd)
            try:
                for component in parts:
                    nxt = os.open(component, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
                    os.close(fd)
                    fd = nxt
                info = os.fstat(fd)
                if stat.S_ISDIR(info.st_mode):
                    names = sorted(os.listdir(fd))
                    os.close(fd)
                    fd = None
                    for name in names:
                        add(path + '/' + name)
                    return
                if not stat.S_ISREG(info.st_mode) or info.st_size > 128 * 1024 * 1024:
                    raise ValueError('nonregular or oversized compiler input: ' + path)
                data = bytearray()
                while True:
                    chunk = os.read(fd, 65536)
                    if not chunk:
                        break
                    data.extend(chunk)
                    if len(data) > 128 * 1024 * 1024:
                        raise ValueError('oversized compiler input: ' + path)
                after = os.fstat(fd)
                if (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
                    raise ValueError('compiler input changed during read: ' + path)
            finally:
                if fd is not None:
                    os.close(fd)
        except FileNotFoundError:
            if optional:
                return
            raise ValueError('missing compiler input: ' + path)
        except OSError as error:
            raise ValueError('unsafe or unreadable compiler input: ' + path) from error
        total += len(data)
        if len(inputs) >= 20000 or total > 512 * 1024 * 1024:
            raise ValueError('compiler inputs exceed fingerprint limit')
        inputs[path] = bytes(data)
        if Path(path).suffix.casefold() == '.odin':
            pending.append(path)

    for root in ('src', 'shared', 'tools', 'data', 'assets'):
        add(root, optional=True)
    while pending:
        source = pending.pop()
        if source in scanned:
            continue
        scanned.add(source)
        try:
            refs = references(inputs[source].decode('utf-8'))
            for kind, target in refs:
                if kind == 'import' and target.startswith(('core:', 'vendor:', 'base:')):
                    # These collections are resolved by the pinned compiler installation.
                    _, tail = target.split(':', 1)
                    if not tail or any(p in ('', '.', '..') for p in tail.split('/')) or any(c in tail for c in ('\\', '\x00', ':')):
                        raise ValueError('unsafe compiler collection path: ' + target)
                    continue
                if kind == 'foreign' and target.startswith('system:'):
                    if not re.fullmatch(r'[A-Za-z0-9_+.-]+', target[len('system:'):]):
                        raise ValueError('system library must be a toolchain library name: ' + target)
                    continue
                if not target or ':' in target or '\\' in target or '\x00' in target or Path(target).is_absolute():
                    raise ValueError('external or unsupported compiler input: ' + target)
                parts = list(Path(source).parent.parts)
                for component in target.split('/'):
                    if component in ('', '.'):
                        continue
                    if component == '..':
                        if not parts:
                            raise ValueError('compiler input points outside the project: ' + target)
                        parts.pop()
                    else:
                        parts.append(component)
                        # Check before collapsing '..': a symlink/../ path can otherwise
                        # resolve differently for the compiler and the fingerprint scanner.
                        if workspace.root.joinpath(*parts).is_symlink():
                            raise ValueError('symlinked compiler input: ' + target)
                if not parts:
                    raise ValueError('compiler input points at the project root: ' + target)
                normalized = '/'.join(parts)
                # add() refuses every symlink component, including those escaping the project.
                add(normalized)
        except (ValueError, UnicodeError) as error:
            raise ValueError(source + ': ' + str(error)) from error
    return inputs
