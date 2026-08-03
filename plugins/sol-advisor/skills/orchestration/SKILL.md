---
name: orchestration
description: "Sol-led architect and delegation workflow using native role-pinned GPT-5.6 Luna / Max for routine implementation, GPT-5.6 Terra / Max for harder implementation, optional Claude Fable 5 / Max specialist implementation or adversarial review, and a mandatory fresh GPT-5.6 Sol / High requested-read-only final review. Use for delegated implementation, multi-task builds, features, bug fixes, refactors, migrations, lane selection, five-part implementation specs, parent verification, commitment-boundary advice, and final independent-context review."
---

# Sol Advisor Orchestration

Act as the architect. Own the user's intent, architecture, decomposition, routing,
verification, and final acceptance. Delegate implementation volume to the least
expensive adequate lane, then obtain a fresh Sol verdict before reporting a deliverable
complete.

Luna, Terra, and Sol are native Codex custom-agent threads. Fable is an optional
external Claude Code lane invoked by the shipped runner; it is never compulsory and
never replaces the final Sol review.

Read [references/role-contracts.md](references/role-contracts.md) before the first
delegation in a session. It defines the required implementation spec, reports, Fable
packets, and final-review packet.

## Confirm the primary session

Run the primary Codex session on `gpt-5.6-sol` at **High or above**. Accepted reasoning
efforts are exactly `high`, `xhigh`, `max`, and `ultra`.

Require runtime metadata to prove both an exact `gpt-5.6-sol` model and an effort in
the exact accepted set: `high`, `xhigh`, `max`, or `ultra`. If either field is omitted,
ask the user to confirm the missing field and stop until it is confirmed. If the model
differs or the effort falls outside that four-value set, stop before delegation. Do not
demand an exact High match and never ask a user to lower `xhigh`, `max`, or `ultra`.
A skill cannot change the primary model or effort itself; never assume or claim this
prerequisite is satisfied.

This flexible gate applies only to the primary Sol session. The installed native roles
remain exact pins: Luna / Max, Terra / Max, and reviewer Sol / High.

## Preflight the native companion agents

The three role files are user-owned native custom-agent TOML files. Installing or
updating the plugin does not automatically register them. Install them separately and
start a fresh Codex task so native discovery sees the current profiles.

Before every native delegation, complete steps 1–2. After spawning a native lane,
complete steps 3–4 before accepting its result:

1. Resolve `../../scripts/install-agents.sh` relative to this SKILL.md and run its
   non-mutating exactness check:

   ~~~sh
   skill_dir=<directory-containing-this-SKILL.md>
   installer="$skill_dir/../../scripts/install-agents.sh"
   sh "$installer" --check
   ~~~

   It must exit zero. This proves Luna, Terra, and Sol match the shipped templates
   exactly. The installer may migrate only the byte-exact v0.3.0 Terra / High profile
   back to Terra / Max and may restore a missing Luna file; it refuses modified,
   nonregular, or symlinked destinations.

2. Inspect the native spawn tool's available `agent_type` entries. All three exact
   names must be exposed:

   - `sol_advisor_luna_implementer`
   - `sol_advisor_terra_implementer`
   - `sol_advisor_sol_reviewer`

   If an affected name is missing, tell the user to install/check the companions,
   start a fresh task, and update Codex if it remains unavailable. Never substitute a
   built-in or similarly named role.

3. Treat exact templates plus observed runtime routing as an acceptance gate. Inspect
   public native spawn/details metadata first. It must identify the selected custom
   role. When it exposes model or effort, compare them with the exact role pin.

   If public details omit model or effort and the local rollout is accessible, resolve
   `../../scripts/inspect-agent-runtime.sh` relative to this SKILL.md and run:

   ~~~sh
   skill_dir=<directory-containing-this-SKILL.md>
   runtime_inspector="$skill_dir/../../scripts/inspect-agent-runtime.sh"
   sh "$runtime_inspector" <native-subagent-thread-id>
   ~~~

   The helper's allowlisted output is the authoritative local fallback for omitted
   model and effort. If public and local values both exist, they must agree. Accepted
   native values are Luna / max for routine implementation, Terra / max for harder
   implementation, and Sol / high for review. Missing, inconsistent, unavailable, or
   unobservable routing stops that native lane.

4. For every Sol review, capture the observed sandbox policy type and permission
   profile type. The shipped reviewer requests read-only sandboxing, but the host may
   broaden it. Never call the review OS-enforced read-only unless the observed sandbox
   policy type is `read-only`.

The custom-agent TOML, not the spawn call, pins model and effort. Never add per-spawn
model or reasoning overrides to native lanes.

## Keep architect work in the primary session

Keep these responsibilities in the primary session:

- Resolve requirements and material ambiguity.
- Choose architecture, interfaces, and decomposition.
- Select one implementation lane per owned file set.
- Write the complete five-part implementation specification.
- Inspect the actual diff and rerun verification.
- Judge reviewer feedback and accept the deliverable.

Do not type implementation code, tests, boilerplate, or mechanical configuration in
the primary session when a lane can do it. If a lane's result is wrong, correct the
specification and delegate the fix. Do not silently repair a failed worker patch.

## Route implementation

### Luna / Max: default routine lane

Use Luna when the specification largely determines the result: boilerplate, wiring,
CRUD, mechanical edits, straightforward features, routine test additions, and bounded
bug fixes.

Spawn exactly:

~~~text
agent_type: sol_advisor_luna_implementer
fork_turns: none
~~~

The installed role pins GPT-5.6 Luna at max reasoning. Omit per-spawn model and effort
fields, and require the native runtime evidence gate before accepting its work.

### Terra / Max: harder native lane

Use Terra when correctness depends on context or judgment the specification cannot
fully encode: subtle concurrency, non-trivial algorithms, security-sensitive paths,
difficult debugging, broad refactors, or larger blast radius. Also escalate after one
Luna attempt proves the task was misclassified; correct the specification first.

Spawn exactly:

~~~text
agent_type: sol_advisor_terra_implementer
fork_turns: none
~~~

The installed role pins GPT-5.6 Terra at max reasoning. Omit per-spawn model and effort
fields, and require the native runtime evidence gate before accepting its work.

### Fable / Max: optional specialist lane

Fable is an alternate writer, not an extra implementation hop. Select it **instead of**
Luna or Terra for an owned file set only when at least one of these is material:

- High-fidelity frontend, visual, game, or design implementation benefits from vision
  and explicit comparison with screenshots or rendered output.
- A large migration or long-horizon implementation benefits from sustained autonomy
  and fewer parent/worker correction turns.
- The stack is unfamiliar or the task benefits from a materially different model
  family's implementation judgment.
- The user explicitly requests Claude or Fable for implementation.

Do not select Fable merely because it is prestigious. Keep routine mechanical work on
Luna. Do not use Fable and a native implementer concurrently on the same files. Do not
use Fable as an unchanged retry after another lane fails; correct the specification and
state why the task shape now warrants Fable.

Write the complete five-part Fable implementation packet from the role contracts to a
regular prompt file. Because the runner uses Claude Code safe mode, include every
relevant repository rule and convention in the packet's `CONSTRAINTS`; do not rely on
Claude plugins, hooks, memory, or `CLAUDE.md` discovery. Then resolve and invoke the
shipped runner:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
fable_runner="$skill_dir/../../scripts/run-fable-agent.sh"
sh "$fable_runner" \
  --mode implement \
  --workdir <absolute-repository-path> \
  --prompt-file <absolute-prompt-file>
~~~

The runner pins the Claude Code `fable` alias at max effort, uses an edit-capable
permission profile, returns structured JSON, and refuses output that does not prove
Fable 5 usage. A Fable safeguard fallback to another Claude model must not be described
as a Fable implementation. Treat the result as a claim: inspect its actual diff and
rerun every verification command in the primary session.

Fable uses the user's separate Claude account or credits. A `--max-budget-usd` cap may
be supplied for metered API execution, but Fable remains optional and an unavailable
Claude account does not block native Luna, Terra, or final Sol review.

### Shared routing rules

- Route by task shape, not model prestige.
- Give every writer one exact owned file set or bounded responsibility.
- State that it is not alone in the codebase, must preserve other edits, and must
  adapt to concurrent changes.
- Run independent non-overlapping work concurrently only when useful. Keep shared-file
  edits and dependency chains serial.
- Never let two agents edit the same owned files concurrently.
- Never silently substitute a role, model, or effort.
- Give a failed lane a corrected specification; never repeat an unchanged prompt.

## Verify every implementation

Treat every worker report as a claim. Before acceptance:

1. Inspect the working tree and complete diff.
2. Confirm only in-scope files changed.
3. Rerun the specification's verification commands in the primary session.
4. Compare the evidence with the objective, interfaces, and constraints.
5. Delegate corrections when the evidence or diff is wrong.

## Optional Fable adversarial review

Fable adversarial review is cross-model-family advice, not a completion gate. Use it
selectively after primary verification when one or more of these applies:

- A consequential architecture, migration, security boundary, public API, or wide
  refactor would benefit from an independent model family.
- The change is visually ambitious and should be challenged against the stated design
  goal or screenshots.
- Native implementation produced mixed evidence or the primary session suspects a
  shared OpenAI-family blind spot.
- The user explicitly requests adversarial or cross-vendor review.

Skip it for routine changes. Skip it when Fable implemented the same change; the
mandatory fresh Sol review already supplies the cross-family challenge in that case.
Never let the Fable reviewer implement its own findings.

Write the adversarial-review packet from the role contracts to a regular prompt file,
including the full accumulated diff and primary verification evidence, then run:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
fable_runner="$skill_dir/../../scripts/run-fable-agent.sh"
sh "$fable_runner" \
  --mode review \
  --workdir <absolute-repository-path> \
  --prompt-file <absolute-prompt-file>
~~~

The runner uses Claude Code safe mode, auto-denies permission prompts, and exposes only
Read, Grep, and Glob tools. The parent must still compare exact before-and-after
repository state. `pass`, `concerns`, or `block` is advisory: judge the evidence,
delegate required fixes, verify again, and continue to the mandatory fresh Sol review.

## Consult Sol at commitment boundaries

Before a consequential architecture, migration, public API, or wide refactor, a fresh
native Sol consult remains available regardless of whether optional Fable review is
also warranted:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

Use the commitment-boundary packet from the role contracts. The installed role pins
Sol / High and requests read-only isolation. Omit per-spawn model and effort fields.
Observe actual routing, sandbox, and permission metadata. The primary session remains
responsible for the decision.

## Require the final Sol review

After implementation and parent verification, always spawn a new, fresh reviewer:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

Use the final-review packet from the role contracts. Instruct the reviewer to remain
behaviorally read-only, inspect the actual files and accumulated diff, and return
exactly `ship`, `fix-first`, or `rethink`.

- `ship`: report completion with verification evidence.
- `fix-first`: delegate required fixes, verify again, and obtain a new review.
- `rethink`: revise architecture and do not report completion.

Never waive the final Sol review because Fable reviewed the change or because the
change is small. Never let the reviewer implement its own fixes. Sol-on-Sol review is
context-clean, not model-family-independent; optional Fable review is the separate
cross-family mechanism.

Apply the observed sandbox policy:

- If it is `read-only`, isolation is enforced.
- If the host broadens it, proceed only when hard isolation is not required, the
  prompt forbids edits, and the parent captures and verifies exact before-and-after
  repository and artifact state. Report the observed sandbox and permission profile.
- If hard isolation is required, the sandbox is unobservable, or any mutation occurs,
  stop the review. Do not claim read-only isolation or hide the mutation.
