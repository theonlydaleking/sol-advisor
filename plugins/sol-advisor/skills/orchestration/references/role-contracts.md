# Sol Advisor role contracts

Use these contracts with Sol Advisor's native Codex roles and optional external Fable
lanes. Adapt every placeholder without removing a required field.

The primary Sol session must be `gpt-5.6-sol` at High or above: `high`, `xhigh`, `max`,
or `ultra`. This flexible gate applies only to the primary architect. Native companions
remain exact pins: Luna / Max, Terra / Max, and reviewer Sol / High.

## Required native-agent preflight

Before every native spawn, complete steps 1–2 of SKILL.md's preflight. After spawning,
complete steps 3–4 before accepting the lane's result:

1. Require the non-mutating companion check to prove Luna, Terra, and Sol exactly match
   current templates.
2. Require native exposure of exactly `sol_advisor_luna_implementer`,
   `sol_advisor_terra_implementer`, and `sol_advisor_sol_reviewer`.
3. Observe the selected role, model, and effort through public spawn/details metadata
   first, using the local runtime inspector only for omitted fields. Accept only Luna /
   max, Terra / max, or reviewer Sol / high according to the chosen role.
4. For the reviewer, capture actual sandbox policy and permission profile types.

A missing, stale, unsafe, conflicting, unavailable, inconsistent, or unobservable
role/model/effort stops that native lane. Never silently fall back. Model and effort are
pinned by custom-agent TOML, so omit per-spawn overrides.

## Shared five-part implementation contract

Every Luna, Terra, or Fable implementation prompt must contain all five sections:

~~~text
OBJECTIVE
<Observable outcome and why it matters.>

FILES AND OWNERSHIP
You own only:
- <exact file or module>

You are not alone in the codebase. Other agents or the user may be editing concurrently.
Preserve their edits, do not revert unrelated work, and adapt to changes already present.
Do not modify files outside your ownership.

INTERFACES
- <Signatures, types, schemas, commands, or behavior that must remain compatible.>

CONSTRAINTS
- <Repository conventions, safety boundaries, excluded scope, and settled decisions.>

VERIFICATION
- Run: <exact command>
  Success: <concrete expected result>
- Inspect: <exact file, diff, screenshot, or generated artifact>
  Success: <concrete expected evidence>

RETURN
Return exact commands and actual evidence. A completion claim without evidence is invalid.

IMPLEMENTATION REPORT
STATUS: complete | partial | blocked
OBJECTIVE: <one-line restatement>
CHANGES: <file-by-file summary from the actual diff>
VERIFIED: <exact commands plus concrete output evidence>
JUDGMENT CALLS: <decisions the specification left open, or none>
GAPS: <unfinished work, ambiguity, or none>
~~~

The primary session must inspect the actual diff and rerun verification itself.

## Luna / Max — routine implementer

Use for bounded work whose result is largely determined by the specification.

Spawn exactly:

~~~text
agent_type: sol_advisor_luna_implementer
fork_turns: none
~~~

The installed role pins GPT-5.6 Luna at max reasoning. Do not attach per-spawn model or
effort fields. Require public-details-first runtime evidence before accepting its work.

Prompt:

~~~text
ROLE
Act as Sol Advisor's routine implementation worker. Execute the specification exactly;
surface ambiguity instead of redesigning the architecture.

<paste and complete the Shared five-part implementation contract>
~~~

## Terra / Max — complex implementer

Use when correctness depends on context, judgment, difficult debugging, non-trivial
algorithms, security-sensitive paths, broad refactors, or larger blast radius.

Spawn exactly:

~~~text
agent_type: sol_advisor_terra_implementer
fork_turns: none
~~~

The installed role pins GPT-5.6 Terra at max reasoning. Do not attach per-spawn model
or effort fields. Require public-details-first runtime evidence before accepting its
work.

Prompt:

~~~text
ROLE
Act as Sol Advisor's complex implementation worker. Resolve difficult implementation
details within the settled architecture, document material judgment calls, and
preserve every stated interface and constraint.

<paste and complete the Shared five-part implementation contract>
~~~

## Fable / Max — optional specialist implementer

Fable is an external Claude Code lane, not a native Codex custom agent. Use it instead
of Luna or Terra for an owned file set only when the routing rules in SKILL.md select
Fable for visual fidelity, long-horizon work, large migration scope, unfamiliar tools,
cross-family judgment, or an explicit user request.

The runner uses Claude Code safe mode. Copy every relevant repository instruction,
convention, and excluded path into the packet rather than relying on Claude's global or
project configuration. Write this packet to a regular prompt file and pass it to
`../../scripts/run-fable-agent.sh --mode implement`:

~~~text
ROLE
Act as Sol Advisor's optional Claude Fable implementation specialist. You are the sole
writer for the exact owned files below. Work within the settled architecture. Do not
delegate, broaden scope, or modify files outside ownership.

<paste and complete the Shared five-part implementation contract>

FABLE-SPECIFIC EVIDENCE
- For visual work, inspect: <rendered page, screenshot, or supplied visual reference>
  Success: <observable fidelity and responsive behavior>
- Report any task that could not be completed because a tool, permission, or model
  safeguard blocked the requested work.
~~~

The runner pins the `fable` alias at max effort and returns Claude Code JSON. Accept
the lane only when the output proves Fable 5 usage, the diff stays within ownership,
and the primary session reruns verification. A fallback model is not Fable evidence.

## Optional Fable adversarial reviewer

This is advisory and cross-model-family. Use it selectively under SKILL.md's criteria;
never make it a universal completion gate. Do not use it to review Fable's own
implementation unless the user explicitly wants same-family review for another reason.

Capture the exact repository and artifact state before invoking it. The runner uses
Claude Code safe mode, so include all relevant repository rules in the packet. Write
this packet to a regular prompt file and pass it to
`../../scripts/run-fable-agent.sh --mode review`:

~~~text
ROLE
Act as an external Claude Fable adversarial reviewer. Remain strictly read-only. Do not
edit files, execute shell commands, or implement fixes.

STATED GOAL
<The user's requested outcome.>

IMPLEMENTATION LANE
<Luna / Max, Terra / Max, or other exact producer evidence.>

ACCUMULATED CHANGE SET
<Complete diff or explicit base/head revisions, plus exact allowed files.>

INTERFACES AND CONSTRAINTS
- <Compatibility, repository rules, safety boundaries, design goal, and excluded scope.>

VERIFICATION EVIDENCE
- <command> -> <actual primary-session output>
- <artifact, browser journey, or screenshot> -> <actual evidence>

ADVERSARIAL REVIEW
Challenge correctness, completeness, architecture assumptions, regressions, scope,
test adequacy, and visual fidelity where relevant. Prefer concrete counterexamples over
style opinions. Separate required defects from optional improvements.

FABLE ADVERSARIAL REVIEW
VERDICT: pass | concerns | block
REASON: <decisive evidence-based reason>
FINDINGS: <precise file references and required fixes, or none>
RESIDUAL RISK: <largest remaining risk, or none>
~~~

After the call, verify exact before-and-after repository and artifact state. Judge the
findings in the primary Sol session. Required fixes go back to an implementation lane,
followed by parent verification. This reviewer never replaces the mandatory fresh Sol
review.

## Fresh Sol / High — requested-read-only final reviewer

After implementation and primary verification, spawn a new native thread exactly:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

The installed role pins GPT-5.6 Sol at high reasoning and requests a read-only sandbox.
Do not attach per-spawn model or effort fields. Observe the actual role, pin, sandbox
policy, and permission profile before accepting its verdict.

Prompt:

~~~text
ROLE
Act as the fresh final reviewer. Remain strictly read-only: do not edit files,
implement fixes, or broaden scope.

STATED GOAL
<The user's requested outcome.>

ACCUMULATED CHANGE SET
<Exact allowed files plus complete working-tree diff, or explicit base/head revisions.>

INTERFACES AND CONSTRAINTS
- <Compatibility, repository rules, safety boundaries, and excluded scope.>

VERIFICATION EVIDENCE
- <command> -> <actual primary-session output evidence>
- <artifact or diff inspection> -> <actual evidence>

OPTIONAL ADVERSARIAL EVIDENCE
<Fable verdict and findings when used, or explicitly "not used; optional lane not warranted".>

REVIEW
Inspect the actual files and accumulated change set. Judge correctness, completeness,
regressions, scope discipline, interface preservation, test adequacy, and material risk.

SOL REVIEW
VERDICT: ship | fix-first | rethink
REASON: <decisive evidence-based reason>
FINDINGS: <precise file references and required fixes, or none>
RESIDUAL RISK: <most important remaining risk, or none>
~~~

If any fix is made after review, discard the verdict and run a new fresh review.
Sol reviewing Sol is context-clean, not cross-model-family independence.

Use observed isolation, not requested isolation:

- With observed `read-only`, proceed with enforced isolation.
- If the host broadens it, proceed only when hard isolation is not required, the
  prompt forbids edits, and the parent captures and verifies exact before-and-after
  repository and artifact state. Report the broader policy and profile.
- If isolation is unobservable, hard isolation is required, or any mutation occurs,
  stop the lane and do not hide or repair the mutation under that verdict.

## Commitment-boundary Sol consult

For pre-implementation review, spawn the same fresh Sol role with `fork_turns: none`.
Give it the proposed decision, goal, constraints, relevant paths, alternatives, and the
one question that changes the plan. Require `proceed`, `change`, or `stop`, plus the
decisive reason and largest risk. Apply the same native preflight, runtime-observation,
sandbox-reporting, and no-fallback rules.
