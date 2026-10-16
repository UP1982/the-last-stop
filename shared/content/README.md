# E0a content API

`shared/content` has no raylib dependency. `load_chapter(root, CHAPTER_PATH,
allocator)` reads the complete referenced graph; `validate_sources` validates an
in-memory candidate. A result contains either an immutable snapshot or diagnostics.
Never use a partial candidate. Every successful snapshot includes typed chapter,
scene, dialogue and asset definitions alongside its source DOM and exact bytes.
`find_scene` returns a borrowed pointer valid until snapshot destruction.

`destroy_load_result(&result)` releases all owned memory and clears the result.
To transfer a successful snapshot, save its pointer and set `result.snapshot=nil`
before destroying the result. The recipient must call `destroy_snapshot` once.
All persistent allocations and bookkeeping use the supplied allocator. No snapshot
borrows input buffers or a temporary allocator. Allocation failures follow Odin's
normal allocator behavior; inputs are bounded before DOM allocation.

The strict adapter uses the installed JSON tokenizer, closes its grammar/range/
EOF/escape gaps, and then uses duplicate-key-aware DOM parsing. The installed DOM
silently omits empty keys, so the adapter rejects them (no content/protocol object
allows an empty field or identity). Input limits are 256 KiB per JSON document,
32 nesting levels, 65,536 tokens, 64 dependencies, 16 MiB per binary asset, and
32 MiB per graph. Schema maps have at most 1,024 records. Geometry uses bounded
integer virtual pixels. The provisional player footprint is 12x16 bottom-centre
(A1); M1 must confirm it. These are authoring safety checks, not a native playtest.

Revisions are `sha256:` followed by lowercase hex. Each dependency gets SHA-256
of its exact bytes. Sort project-relative dependency paths by byte order. Hash
this concatenation for every entry:

```
u64 big-endian UTF-8 path length | UTF-8 path bytes |
u64 big-endian digest length (32) | 32 raw digest bytes
```

Binary assets participate too. No mtime/counter participates. Discovery only
follows explicit references; `data/legacy` and JSON Schemas are not runtime data.
Dependency paths use `/`; absolute paths, traversal, control characters and
symlink components are rejected. The CLI pins the root with POSIX `realpath`.
Assets include declared hashes and provenance; native texture decoding belongs
to E0b's resource-staging step.

# Structured edits

Build with `odin build tools/content -out:build/tls-content`. Commands:

```
build/tls-content validate-content --project-root .
build/tls-content inspect-scene --project-root . --scene oliver_obstacle
build/tls-content apply-edit --project-root . --request edit.json
```

JSON goes to stdout; exit codes: 0 success (including no-op), 2 invalid data or
request, 3 stale/busy/external-change conflict, 4 I/O failure before commit,
5 committed with uncertain durability. Inspect `commit_state`, not exit code
alone. Validation and inspection report `not_committed` because they do not write.

The strict protocol-v1 request envelope is shown in
`tests/editor/fixtures/move-handle.json`; replace its all-zero revision with the
current graph revision. A request targets one existing document ID. It may use:

- `create`: `collection`, fresh `id`, complete record in `value`.
- `delete`: `collection`, `id`.
- `set_property`: `collection`, `id`, `property`, `value`.
- `link_object`: scene puzzle `role`, `target` ID (object or spawn for that role).
- `update_dialogue`: existing line `id`, `speaker` and/or `text`.
- `set_order`: complete `order` array, every line exactly once.
- `restore_document`: complete document in `value`, preserving kind/ID/version.

Collections: scene `objects`/`spawns`, dialogue `lines`, chapter
`speakers`/`keepsakes`, manifest `assets`. Set-property allowlists:
objects `position,size,layer,collision,interaction,asset`; spawns `position`;
speakers `name,species`; keepsakes `name`; assets
`frame_size,frame_count,pivot,provenance`. Paths and identities cannot be assigned
through set-property. Dialogue changes use update-dialogue. A whole batch is
validated after all operations, so create-line + set-order is atomic.

`request_parse` owns the decoded request until `destroy_request_result`.
`prepare_edit` is read-only; a successful prepared edit is released with
`destroy_prepared_edit`. Failure diagnostics from prepare use the supplied
allocator (prefer a request-scoped allocation domain). `apply_edit` returns an
owned result released with `destroy_edit_result`. Direct callers must use a
strictly decoded request, as the CLI does.

Managed writers hold a nonblocking POSIX F_SETLK write lock on the permanent
`.studio/content.lock` descriptor. Under that lock, they reload/compare the graph,
prepare/validate/serialize/revalidate, and durably persist complete before/after
images plus `prepared.json` under `.studio/history/txn-*`. Then they exclusively
create a temp beside the destination, write/sync/close, recheck graph hashes,
and rename over one destination. Rename is the commit point. Parent-directory
sync and `committed.json` finalization follow. No-op requests preserve original
bytes and revision, and create no history transaction.

After interruption or a lost response, compare current bytes/hash/revision with
`prepared.json`, `before.json` and `after.json`. `committed.json` confirms normal
finalization; its absence does not prove rename did not happen. Undo/redo are
new restore-document requests with the current graph revision. Recovery files
are never pruned automatically. SIGKILL before rename can leave a complete temp
beside the destination; history also retains the candidate. Do not blindly replay
an uncertain create/delete. All Studio/agent writers must use this interface.
An unmanaged writer ignoring the lock can race the final recheck/rename; direct
external editing must happen while managed writes are idle. POSIX files do not
provide atomic compare-and-swap.

# Verification

`./scripts/check.sh` checks existing src, checks the library, builds the production
CLI, runs Odin allocation tests, then Python stdlib behavioral tests. Python builds
a separate `build/tls-content-test` with `-define:E0_TEST_HOOKS=true`. Only that
binary reads `TLS_E0_FAULT`, `TLS_E0_PAUSE`, `TLS_E0_MARKER`; production ignores
them. Tests use disposable project copies under build and include real F_SETLK
contention, SIGKILL before/after rename, exact-byte checks, history restoration,
and injected short-write/temp/sync/close/rename/history/durability failures.
Native runtime loading/preview, reload retention, saves and gameplay are E0b or
later work; this package does not claim those gates.
