'use strict';
// Recovery is private project data. It never applies edits or rebases preconditions.
window.TLSDrafts = {
  create(command, report) {
    const records = new Map();
    const key = (kind, id) => `${kind}:${id}`;
    function state(kind, id) {
      const k = key(kind, id);
      if (!records.has(k)) records.set(k, {tail: Promise.resolve(), sha: null, error: null, loaded: false, pending: 0});
      return records.get(k);
    }
    function feedback() {
      const failed = [...records.values()].find(record => record.error);
      if (failed) report(`Recovery not saved: ${failed.error.message}. Download drafts before closing.`);
      else report([...records.values()].some(record => record.pending) ? 'Saving recovery draft…' : 'Recovery draft saved in this project.');
    }
    return {
      async read(kind, id) {
        const record = state(kind, id);
        await record.tail;
        if (record.error) { feedback(); return null; }
        try {
          const response = await command('read-draft', {kind, id});
          record.sha = response.sha256; record.loaded = true;
          return response.value;
        } catch (error) {
          // Keep disk inspection usable on a read-only/unavailable recovery drive.
          // This session cannot replace an unknown recovery baseline.
          record.error = error; feedback(); return null;
        }
      },
      store(kind, id, value) {
        const record = state(kind, id), snapshot = JSON.parse(JSON.stringify(value));
        record.pending++; feedback();
        record.tail = record.tail.then(async () => {
          if (record.error) throw record.error;
          if (!record.loaded) throw Error('Recovery baseline unavailable');
          const response = await command('write-draft', {kind, id, expected_sha256: record.sha, value: snapshot});
          record.sha = response.sha256;
        }).catch(error => {
          record.error = error;
        }).finally(() => { record.pending--; feedback(); });
      },
      async flush() {
        await Promise.all([...records.values()].map(record => record.tail));
        const failed = [...records.values()].find(record => record.error);
        if (failed) throw failed.error;
      }
    };
  }
};
