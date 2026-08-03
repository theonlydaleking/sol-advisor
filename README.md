# Sol Advisor

**Sol runs the show at High or above. Luna / Max handles routine implementation,
Terra / Max takes the harder builds, optional Fable / Max provides a cross-vendor
specialist lane, and a fresh Sol / High review stands between the diff and done.**

Sol Advisor is a Codex-native architect workflow for capability-routed software
delivery. The primary session stays focused on requirements, architecture, specs, and
verification while native Codex custom-agent threads handle implementation and review.
Claude Fable is available as an optional external implementation or adversarial-review
lane; it is never required for completion.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

| Lane | Native agent type | Pinned profile | Use it for |
|---|---|---|---|
| Orchestrator | Primary session | GPT-5.6 Sol / High or above | Requirements, architecture, decomposition, routing, and acceptance |
| Routine implementation | sol_advisor_luna_implementer | GPT-5.6 Luna / Max | Mechanical, repeatable, fully specified work |
| Harder implementation | sol_advisor_terra_implementer | GPT-5.6 Terra / Max | Context-heavy, higher-risk, or wider-blast-radius work |
| Optional specialist | External Claude Code runner | Claude Fable 5 / Max | Visual, long-horizon, migration, or cross-family implementation |
| Optional adversarial review | External Claude Code runner | Claude Fable 5 / Max / restricted read-only tools | Selective cross-family challenge; never a completion gate |
| Final review | sol_advisor_sol_reviewer | GPT-5.6 Sol / High / requests read-only | Fresh review of the actual diff and verification evidence |

The final review is context-independent, not model-family-independent: Sol reviews
Sol's orchestration with a fresh context. That catches conversational assumptions, but
it is not cross-vendor review. The optional Fable adversarial lane supplies that
cross-family perspective when the task warrants it.

## Install from GitHub

Requirements:

- A current Codex CLI or ChatGPT desktop app with plugins, native subagents, and
  custom agents enabled.
- Access to GPT-5.6 Sol at High or above, GPT-5.6 Luna / Max, and GPT-5.6 Terra / Max.
- Optional: Claude Code with access to the `fable` alias for Fable specialist lanes.
- jq, which the companion-install lookup uses to locate the installed plugin package.

Add the GitHub repository as a Codex marketplace, then install the plugin:

~~~sh
codex plugin marketplace add theonlydaleking/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
~~~

### Install the companion custom agents

Plugin installation does **not** automatically install custom-agent files. That is
intentional: the files are user-owned role pins, and the installer must never overwrite
a different local role silently. Install the companion templates separately:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -n "$plugin_dir"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

Without an explicit target, the installer uses the existing CODEX_HOME value when one is
already set, otherwise the user's default Codex agents directory. It does not invoke
Codex, edit config.toml, or overwrite a differing agent file. It only installs a
missing template and then verifies every installed copy byte-for-byte.

Start a **new Codex task** after the check passes. Native agent types are discovered at
task creation, so an existing task may not see the installed roles.

Then select GPT-5.6 Sol with High, Extra High, Max, or Ultra reasoning for the primary
session and ask for implementation work normally, or invoke the orchestration skill
explicitly. The primary gate is **at least High**, not exactly High:

~~~text
Use $sol-advisor:orchestration to build this feature, verify it, and obtain the final Sol review before reporting done.
~~~

## Check and update

Run this check whenever a route must be trusted:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

To update the marketplace plugin and migrate the exact recognized v0.3.0 Terra / High
companion:

~~~sh
codex plugin marketplace upgrade sol-advisor
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

Version 0.4.1 restores the v0.2.0 routing contract. Normal installer mode recognizes
only the byte-exact v0.3.0 Terra / High profile, migrates it back to Terra / Max,
restores a missing Luna / Max profile, and refuses modified, nonregular, or symlinked
destinations without partial agent-file mutation. Existing byte-exact v0.2.0 Luna /
Max, Terra / Max, and Sol / High profiles are already current. `--check` is
non-mutating and fails until all three current roles match exactly.

Do not use a substitute agent as a shortcut. Start a fresh task after every successful
install or update.

## Runtime routing evidence

Native spawn/details metadata is the primary source of routing evidence. It must show
the selected custom agent type. When it also exposes model and effort, the orchestrator
compares those values with the role pin. If Desktop omits model or effort and the local
rollout is accessible, use the companion inspector as the authoritative read-only
fallback for those omitted fields:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
thread_id="<native-subagent-thread-id>"
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$thread_id"
~~~

For a disposable fixture or a non-default local session root, pass it explicitly:

~~~sh
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" --sessions-dir /absolute/path/to/sessions "$thread_id"
~~~

The helper searches only rollout filenames ending in that exact thread id, then emits a
single compact JSON object with allowlisted routing fields. It never prints prompts,
messages, environment variables, tokens, configuration contents, or arbitrary rollout
payloads. It refuses invalid ids, zero or multiple matches, and missing or inconsistent
role/model/effort; there is no inferred fallback. If public and local evidence both
exist, they must agree.

## How routing works

The Sol orchestrator writes a five-part spec for every implementation: objective, file
ownership, interfaces, constraints, and verification. Luna / Max is the routine native
producer. Terra / Max handles context-heavy, higher-risk, or wider-blast-radius work.
Fable / Max is an optional alternate writer for visual, long-horizon, migration, or
cross-family tasks. It replaces a native writer for an owned file set; it is not an
extra compulsory implementation hop.

Before delegation and acceptance, the skill requires all of the following:

1. The installed role files pass the byte-for-byte companion check.
2. The native spawn tool exposes all three native names in the table above.
3. Public native spawn/details metadata identifies the selected role and, when exposed,
   its expected model and effort. If model or effort is omitted, the exact-rollout local
   inspector above must provide them instead.
4. The reviewer’s observed sandbox policy type and permission profile type are captured
   and reported.

A missing, stale, conflicting, unavailable, inconsistent, or unobservable
role/model/effort stops the affected lane with an actionable error. There is no silent
model, reasoning, or agent-type fallback, and per-spawn calls do not override the role
pins.

The Sol reviewer TOML requests read-only sandboxing, but the host permission profile
may broaden that request. If the observed sandbox policy type is read-only, review can
proceed with enforced isolation. If the host broadens it, review can proceed only as
behaviorally read-only when hard isolation is not required, the prompt forbids edits,
and the parent captures and verifies exact before-and-after repository/artifact state;
the broader sandbox and permission profile must be reported as residual risk. If hard
isolation is required, the sandbox cannot be observed, or any mutation occurs, stop the
review lane and do not claim enforced read-only isolation.

The orchestrator inspects every diff and reruns verification. A fresh Sol reviewer then
returns ship, fix-first, or rethink. The session cannot report completion until the
reviewer returns ship. Luna, Terra, and Sol remain native Codex threads. Optional
Fable lanes use a separate Claude Code process and never globally reroute unrelated
subagents.

## Optional Fable lanes

The shipped runner invokes Claude Code's `fable` alias at max effort and returns JSON
containing result, usage, and cost metadata. It has two modes:

- `implement`: edit-capable specialist lane for high-fidelity frontend/visual work,
  large migrations, unfamiliar stacks, long-horizon tasks, or explicit user requests.
- `review`: adversarial lane with auto-denied permission prompts and only Read, Grep,
  and Glob tools. Use it selectively for consequential or cross-family review; it
  never replaces final Sol.

The orchestrator writes the relevant packet from `references/role-contracts.md` to a
regular prompt file and invokes:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
sh "$plugin_dir/scripts/run-fable-agent.sh" \
  --mode implement \
  --workdir /absolute/path/to/repository \
  --prompt-file /absolute/path/to/five-part-spec.txt
~~~

Both modes run Claude Code in safe mode to avoid loading unrelated plugins, hooks,
memory, and global skills. The prompt packet must therefore include every relevant
repository rule. Use `--mode review` with the adversarial-review packet for the optional
reviewer. The runner refuses output that does not prove Fable 5 usage. Never run Fable
and a native implementer concurrently on the same files.

## Local development

Install a checkout as a local marketplace when you want Codex to use its skill:

~~~sh
cd /absolute/path/to/sol-advisor
codex plugin marketplace add /absolute/path/to/sol-advisor
codex plugin add sol-advisor@sol-advisor
~~~

Run the repository verifier separately. It uses only a disposable target directory and
never changes your Codex configuration:

~~~sh
cd /absolute/path/to/sol-advisor
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
~~~

To exercise the installer itself against an explicit disposable target:

~~~sh
cd /absolute/path/to/sol-advisor
scratch_agents="$(mktemp -d)"
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$scratch_agents"
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir "$scratch_agents" --check
~~~

To install this checkout's templates for real local development, use the same
repository-relative commands without --target-dir, then begin a new task:

~~~sh
cd /absolute/path/to/sol-advisor
sh plugins/sol-advisor/scripts/install-agents.sh
sh plugins/sol-advisor/scripts/install-agents.sh --check
~~~

After editing the plugin, validate both layers:

~~~sh
cd /absolute/path/to/sol-advisor
if [ -n "$CODEX_HOME" ]; then
  codex_skills="$CODEX_HOME/skills/.system"
else
  codex_skills="$HOME/.codex/skills/.system"
fi
uv run --no-project --with pyyaml python "$codex_skills/skill-creator/scripts/quick_validate.py" plugins/sol-advisor/skills/orchestration
uv run --no-project --with pyyaml python "$codex_skills/plugin-creator/scripts/validate_plugin.py" plugins/sol-advisor
jq empty .agents/plugins/marketplace.json plugins/sol-advisor/.codex-plugin/plugin.json
~~~

The verifier validates JSON and TOML, all three exact native role pins, clean/current/
missing and idempotent installer behavior, exact-v0.3.0 Terra migration, Fable runner
argument/model-proof fixtures, refusal/non-mutation gates, runtime-inspector safe
fixtures, contract references, and shell syntax. The uv commands
supply the validators' PyYAML dependency in a disposable environment. They do not
install the marketplace or mutate Codex configuration.

## License

MIT
