# Assignment templates for Opus

Fill every bracket before delegation. Include the actual assigned checkout path; do not depend on inherited working directory or conversation history. Pass the shared-context path and any essential contract verbatim if the child cannot access the file yet.

## Implementation task

You are [model], assigned [task ID and title] for The Last Stop.

- Checkout root: [absolute path].
- Base commit/current preserved state: [commit and any relevant existing edits].
- Read: `prompts/AGENT_SHARED_CONTEXT.md`, its mandatory references, and [role prompt/additional files].
- Current milestone: [M0–M5].
- Outcome: [one concrete player-visible result].
- Allowed files: [exact files or bounded directories, including allowed new files].
- Read-only/shared files: [paths].
- Required interfaces/invariants: [types, procedure signatures, state ownership, save constraints].
- Required behavior: [specific inputs, transitions and visible results].
- Excluded work: [later milestones, unnecessary systems, unrelated refactors].
- Acceptance checks: [commands plus concrete interactive/state cases].
- Delivery: [shared-checkout diff or worktree commit; do not integrate into main].
- Recursive delegation: not authorized.

Inspect first, implement the smallest coherent change, test, and return the mandatory shared handoff. If an interface must change or acceptance is blocked, give the evidence and smallest proposed resolution. Do not declare an unrun check passed. Stop after this task; do not start the next milestone.

## Astra architecture consultation

Read `prompts/AGENT_SHARED_CONTEXT.md` and [relevant code/docs] in [checkout] at [commit]. You are read-only. Resolve [specific technical decision] for milestone [ID]. Return the smallest viable state/interface contract, invariants, allowed transitions, save/load behavior, concrete failure cases and tests. Consider [constraints]. Do not introduce a generalized engine or rewrite unrelated systems. Distinguish required changes from optional improvements. Opus will accept the contract and assign implementation separately.

## Independent review

Review task [ID], round [number], using [model]. Checkout: [path]. Base: [commit]. Target: [immutable commit/diff]. Read `prompts/AGENT_SHARED_CONTEXT.md`, `prompts/QA_AGENT_PROMPT.md`, [relevant documents] and the actual diff.

Original brief and acceptance criteria: [include them].
Prior findings: [none or full relevant findings].
Author responses/fixes: [responses and changed commit].
Unresolved objections: [list].
Focus: [e.g. save recovery, skip transitions, handle uniqueness, reward idempotence].

Do not modify files. Run permitted checks where feasible and distinguish observed failures from hypotheses. Return findings ordered by severity, each with file/line, triggering steps, expected/actual behavior and suggested minimal remedy. Also list missing acceptance evidence and checks actually run. “No findings” does not imply unperformed native/human tests passed. Do not repeat previously resolved findings without new evidence.

## Haiku support task

Read `prompts/AGENT_SHARED_CONTEXT.md` and [specific role sources] in [checkout]. Produce [exact bounded deliverable]. Allowed files: [list]. Follow this example/schema: [example]. Source facts only from [files/tools]. Mark unknowns explicitly. Validate [specific consistency checks]. Do not edit runtime code/shared documentation outside your assigned files, invent licenses, or label behavior verified from documentation. Return the mandatory handoff.

## Native/manual verification task

Build under test: [path/commit/version]. Launch command: [command]. Environment: [OS/architecture/compiler]. Follow [specific TEST_PLAN cases] in the real game. Capture actual observed behavior and relevant logs/screenshots; include restart tests where specified. Keep save fixtures isolated from the user's real progress. Report pass/fail/unverified for each step and exact reproductions. If you cannot control or inspect the native window, stop claiming interactive coverage and return the remaining test instructions to Opus.
