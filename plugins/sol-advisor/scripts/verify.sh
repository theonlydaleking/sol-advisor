#!/bin/sh
# Repository-local verification for Sol Advisor native roles and optional Fable lanes.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH='' cd "$script_dir/.." && pwd) || exit 1
repo_dir=$(CDPATH='' cd "$plugin_dir/../.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
runtime_inspector=$script_dir/inspect-agent-runtime.sh
fable_runner=$script_dir/run-fable-agent.sh
templates=$plugin_dir/agents
manifest=$plugin_dir/.codex-plugin/plugin.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
readme=$repo_dir/README.md

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_dir=''
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/sol-advisor-verify.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "REFUSING cleanup of unexpected directory: $tmp_dir" >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM
tmp_dir=$(mktemp -d "$tmp_base/sol-advisor-verify.XXXXXX") || fail "could not create disposable verification directory"

luna_file=sol-advisor-luna-implementer.toml
terra_file=sol-advisor-terra-implementer.toml
sol_file=sol-advisor-sol-reviewer.toml
legacy_terra_sha256=06c318e5e93f37452635906394e6ea69fb6a65ba9e6ad7172d37b444e0dc871d

snapshot_files() {
  target=$1
  if [ ! -d "$target" ]; then
    printf '%s\n' MISSING
    return
  fi
  find "$target" -mindepth 1 -maxdepth 1 -print | LC_ALL=C sort | while IFS= read -r path; do
    if [ -L "$path" ]; then
      printf 'L %s -> %s\n' "$(basename "$path")" "$(readlink "$path")"
    elif [ -f "$path" ]; then
      shasum -a 256 "$path"
    else
      printf 'O %s\n' "$(basename "$path")"
    fi
  done
}

write_v030_roles() {
  target=$1
  mkdir -p "$target"
  cat > "$target/$terra_file" <<'LEGACY_TERRA'
name = "sol_advisor_terra_implementer"
description = "Sol Advisor's sole implementation lane for routine and complex work."
model = "gpt-5.6-terra"
model_reasoning_effort = "high"

developer_instructions = """
You are Sol Advisor's sole implementation worker for routine, context-heavy,
higher-risk, and wider-blast-radius work. Execute the supplied five-part specification
within the settled architecture. Preserve every stated interface and constraint, stay
within the owned file set, and document material judgment calls.

You are not alone in the codebase: preserve concurrent edits and do not revert
unrelated work. Surface ambiguity, scope conflicts, or verification failures rather
than redesigning the architecture without direction. Run the requested checks and
report actual evidence. Do not silently substitute a different role, model, or
reasoning level; this installed custom-agent profile is the only implementation lane.
"""
LEGACY_TERRA
  cp "$templates/$sol_file" "$target/$sol_file"
  [ "$(shasum -a 256 "$target/$terra_file" | awk '{print $1}')" = "$legacy_terra_sha256" ] ||
    fail "v0.3.0 Terra fixture digest drifted"
}

for required in "$installer" "$runtime_inspector" "$fable_runner" "$manifest" "$skill" "$contracts" "$readme"; do
  test -f "$required" || fail "required file missing: $required"
done

jq empty "$manifest"
[ "$(jq -r '.version' "$manifest")" = 0.4.0 ] || fail "manifest version is not 0.4.0"
pass "manifest JSON and version"

python3 - "$templates" <<'PY'
from pathlib import Path
import sys, tomllib

root = Path(sys.argv[1])
expected = {
    "sol-advisor-luna-implementer.toml": {
        "name": "sol_advisor_luna_implementer",
        "model": "gpt-5.6-luna",
        "model_reasoning_effort": "max",
    },
    "sol-advisor-terra-implementer.toml": {
        "name": "sol_advisor_terra_implementer",
        "model": "gpt-5.6-terra",
        "model_reasoning_effort": "max",
    },
    "sol-advisor-sol-reviewer.toml": {
        "name": "sol_advisor_sol_reviewer",
        "model": "gpt-5.6-sol",
        "model_reasoning_effort": "high",
        "sandbox_mode": "read-only",
    },
}
actual = {path.name for path in root.glob("*.toml")}
if actual != set(expected):
    raise SystemExit(f"expected exactly {sorted(expected)}, found {sorted(actual)}")
for filename, pins in expected.items():
    data = tomllib.loads((root / filename).read_text(encoding="utf-8"))
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise SystemExit(f"{filename}: missing {field}")
    for field, value in pins.items():
        if data.get(field) != value:
            raise SystemExit(f"{filename}: {field}={data.get(field)!r}, expected {value!r}")
print("three exact native role pins are valid")
PY
pass "exact three-role TOML inventory"

grep -Fq "legacy_terra_sha256=$legacy_terra_sha256" "$installer" || fail "installer v0.3.0 Terra digest mismatch"
pass "immutable v0.3.0 migration fingerprint"

clean_target=$tmp_dir/clean
sh "$installer" --target-dir "$clean_target"
for role_file in "$luna_file" "$terra_file" "$sol_file"; do
  cmp -s "$templates/$role_file" "$clean_target/$role_file" || fail "clean install mismatch: $role_file"
done
sh "$installer" --target-dir "$clean_target" --check
before=$(snapshot_files "$clean_target")
sh "$installer" --target-dir "$clean_target"
after=$(snapshot_files "$clean_target")
[ "$before" = "$after" ] || fail "idempotent install changed current roles"
pass "clean install, exact check, and idempotence"

missing_target=$tmp_dir/missing
if sh "$installer" --target-dir "$missing_target" --check; then fail "--check accepted missing target"; fi
test ! -e "$missing_target" || fail "--check mutated missing target"
pass "missing-target check refusal is non-mutating"

codex_home=$tmp_dir/codex-home
CODEX_HOME="$codex_home" sh "$installer"
for role_file in "$luna_file" "$terra_file" "$sol_file"; do
  cmp -s "$templates/$role_file" "$codex_home/agents/$role_file" || fail "CODEX_HOME mismatch: $role_file"
done
test ! -e "$codex_home/config.toml" || fail "installer created config.toml"
relative_parent=$tmp_dir/relative-parent
mkdir "$relative_parent"
(cd "$relative_parent" && sh "$installer" --target-dir relative-agents)
cmp -s "$templates/$luna_file" "$relative_parent/relative-agents/$luna_file" || fail "relative target Luna mismatch"
pass "CODEX_HOME and relative target behavior"

migration_target=$tmp_dir/migration
write_v030_roles "$migration_target"
sh "$installer" --target-dir "$migration_target"
for role_file in "$luna_file" "$terra_file" "$sol_file"; do
  cmp -s "$templates/$role_file" "$migration_target/$role_file" || fail "v0.3.0 migration mismatch: $role_file"
done
sh "$installer" --target-dir "$migration_target" --check
pass "exact v0.3.0 Terra migration and Luna restoration"

modified_terra=$tmp_dir/modified-terra
write_v030_roles "$modified_terra"
printf '%s\n' modified >> "$modified_terra/$terra_file"
before=$(snapshot_files "$modified_terra")
if sh "$installer" --target-dir "$modified_terra"; then fail "installer replaced modified Terra"; fi
after=$(snapshot_files "$modified_terra")
[ "$before" = "$after" ] || fail "modified-Terra refusal partially mutated target"
test ! -e "$modified_terra/$luna_file" || fail "modified-Terra refusal installed Luna"
pass "modified Terra refusal with zero partial mutation"

modified_luna=$tmp_dir/modified-luna
sh "$installer" --target-dir "$modified_luna"
printf '%s\n' modified >> "$modified_luna/$luna_file"
before=$(snapshot_files "$modified_luna")
if sh "$installer" --target-dir "$modified_luna"; then fail "installer replaced modified Luna"; fi
after=$(snapshot_files "$modified_luna")
[ "$before" = "$after" ] || fail "modified-Luna refusal partially mutated target"
pass "modified Luna refusal with zero partial mutation"

unsafe=$tmp_dir/unsafe
mkdir "$unsafe"
ln -s "$templates/$terra_file" "$unsafe/$terra_file"
before=$(snapshot_files "$unsafe")
if sh "$installer" --target-dir "$unsafe"; then fail "installer accepted symlinked Terra"; fi
after=$(snapshot_files "$unsafe")
[ "$before" = "$after" ] || fail "symlink refusal partially mutated target"
test ! -e "$unsafe/$luna_file" || fail "symlink refusal partially installed Luna"
test ! -e "$unsafe/$sol_file" || fail "symlink refusal partially installed Sol"
pass "unsafe destination refusal with zero partial mutation"

runtime_sessions=$tmp_dir/runtime-sessions
runtime_day=$runtime_sessions/2026/08/03
mkdir -p "$runtime_day"
write_rollout() {
  runtime_id=$1
  runtime_role=$2
  runtime_model=$3
  runtime_effort=$4
  runtime_rollout=$runtime_day/rollout-2026-08-03T00-00-00-$runtime_id.jsonl
  printf '%s\n' \
    '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK_PROMPT"}}' \
    "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"$runtime_role\",\"agent_path\":\"/root/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture\"}}" \
    "{\"type\":\"turn_context\",\"payload\":{\"model\":\"$runtime_model\",\"effort\":\"$runtime_effort\",\"sandbox_policy\":{\"type\":\"danger-full-access\"},\"permission_profile\":{\"type\":\"disabled\"},\"cwd\":\"/fixture\"}}" \
    > "$runtime_rollout"
}

luna_id=11111111-1111-7111-8111-111111111111
terra_id=22222222-2222-7222-8222-222222222222
write_rollout "$luna_id" sol_advisor_luna_implementer gpt-5.6-luna max
write_rollout "$terra_id" sol_advisor_terra_implementer gpt-5.6-terra max
for fixture in "$luna_id:sol_advisor_luna_implementer:gpt-5.6-luna:max" "$terra_id:sol_advisor_terra_implementer:gpt-5.6-terra:max"; do
  old_ifs=$IFS
  IFS=:
  set -- $fixture
  IFS=$old_ifs
  runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$1")
  printf '%s\n' "$runtime_output" | jq -e --arg id "$1" --arg role "$2" --arg model "$3" --arg effort "$4" '
    .thread_id == $id and .agent_role == $role and .model == $model and .effort == $effort
    and .sandbox_policy_type == "danger-full-access" and .permission_profile_type == "disabled"
  ' >/dev/null || fail "runtime inspector returned wrong evidence for $2"
  if printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK; then fail "runtime inspector leaked payload"; fi
done
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" invalid >/dev/null 2>&1; then fail "runtime inspector accepted invalid id"; fi
pass "runtime inspector Luna/Max and Terra/Max routing"

fake_bin=$tmp_dir/fake-bin
mkdir "$fake_bin"
fake_args=$tmp_dir/fake-args
cat > "$fake_bin/claude" <<'FAKE_CLAUDE'
#!/bin/sh
printf '%s\n' "$@" > "$FAKE_CLAUDE_ARGS"
cat >/dev/null
printf '%s\n' '{"result":"ok","total_cost_usd":0,"modelUsage":{"claude-fable-5":{"inputTokens":1,"outputTokens":1}}}'
FAKE_CLAUDE
chmod +x "$fake_bin/claude"
prompt_file=$tmp_dir/prompt.txt
printf '%s\n' 'OBJECTIVE' 'Verify the Fable runner fixture.' > "$prompt_file"

FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode implement --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null
grep -Fxq -- '--model' "$fake_args" || fail "Fable runner omitted model flag"
grep -Fxq -- 'fable' "$fake_args" || fail "Fable runner omitted fable alias"
grep -Fxq -- '--effort' "$fake_args" || fail "Fable runner omitted effort flag"
grep -Fxq -- 'max' "$fake_args" || fail "Fable runner omitted max effort"
grep -Fxq -- 'acceptEdits' "$fake_args" || fail "Fable implementer lacks edit permission mode"
grep -Fxq -- 'Read,Edit,Write,Bash,Grep,Glob' "$fake_args" || fail "Fable implementer tool set drifted"

FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null
grep -Fxq -- '--safe-mode' "$fake_args" || fail "Fable runner does not isolate global customizations"
grep -Fxq -- 'dontAsk' "$fake_args" || fail "Fable reviewer lacks no-prompt permission mode"
grep -Fxq -- 'Read,Grep,Glob' "$fake_args" || fail "Fable reviewer tool set drifted"
if grep -Fxq -- 'Read,Edit,Write,Bash,Grep,Glob' "$fake_args"; then fail "Fable reviewer retained edit tools"; fi

FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" --max-budget-usd 0.75 >/dev/null
grep -Fxq -- '--max-budget-usd' "$fake_args" || fail "Fable runner omitted a valid spend cap"
grep -Fxq -- '0.75' "$fake_args" || fail "Fable runner changed a valid spend cap"
for invalid_budget in 0 . .0 1.2.3; do
  rm -f "$fake_args"
  if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" --max-budget-usd "$invalid_budget" >/dev/null 2>&1; then
    fail "Fable runner accepted invalid spend cap: $invalid_budget"
  fi
  test ! -e "$fake_args" || fail "Fable runner invoked Claude for invalid spend cap: $invalid_budget"
done
rm -f "$fake_args"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" --max-budget-usd '' >/dev/null 2>&1; then
  fail "Fable runner accepted an explicitly empty spend cap"
fi
test ! -e "$fake_args" || fail "Fable runner invoked Claude for an explicitly empty spend cap"
newline_budget=$(printf '1\n_')
newline_budget=${newline_budget%_}
rm -f "$fake_args"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" --max-budget-usd "$newline_budget" >/dev/null 2>&1; then
  fail "Fable runner accepted a newline-terminated spend cap"
fi
test ! -e "$fake_args" || fail "Fable runner invoked Claude for a newline-terminated spend cap"

cat > "$fake_bin/claude" <<'WRONG_MODEL'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"fallback","modelUsage":{"claude-opus-4-8":{"inputTokens":1}}}'
WRONG_MODEL
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted output without Fable model proof"
fi

cat > "$fake_bin/claude" <<'ALIAS_ONLY'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"alias-only","modelUsage":{"fable":{"inputTokens":1}}}'
ALIAS_ONLY
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted an unproven bare alias"
fi

cat > "$fake_bin/claude" <<'MIXED_MODELS'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"mixed","modelUsage":{"claude-fable-5":{"inputTokens":1},"claude-opus-4-8":{"inputTokens":1}}}'
MIXED_MODELS
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted mixed Fable and fallback model usage"
fi

cat > "$fake_bin/claude" <<'DUAL_CONTAINER_MIXED'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"dual-mixed","modelUsage":{"claude-fable-5":{"inputTokens":1}},"model_usage":{"claude-opus-4-8":{"input_tokens":99}}}'
DUAL_CONTAINER_MIXED
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted mixed models split across dual usage containers"
fi

cat > "$fake_bin/claude" <<'DUAL_CONTAINER_INVALID'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"dual-invalid","modelUsage":{"claude-fable-5":{"inputTokens":1}},"model_usage":{"claude-fable-5":{"input_tokens":false,"output_tokens":2}}}'
DUAL_CONTAINER_INVALID
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted invalid tokens hidden in a second usage container"
fi

cat > "$fake_bin/claude" <<'MULTIPLE_DOCUMENTS'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"first","modelUsage":{"claude-opus-4-8":{"inputTokens":1}}}'
printf '%s\n' '{"result":"second","modelUsage":{"claude-fable-5":{"inputTokens":1}}}'
MULTIPLE_DOCUMENTS
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted multiple JSON output documents"
fi

cat > "$fake_bin/claude" <<'VALID_SNAKE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"snake-valid","model_usage":{"claude-fable-5":{"input_tokens":1}}}'
VALID_SNAKE_USAGE
chmod +x "$fake_bin/claude"
FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null ||
  fail "Fable runner rejected a valid single snake-case usage container"

cat > "$fake_bin/claude" <<'ZERO_BYTES'
#!/bin/sh
cat >/dev/null
ZERO_BYTES
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted zero-byte Claude output"
fi

cat > "$fake_bin/claude" <<'EMPTY_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"empty-usage","modelUsage":{}}'
EMPTY_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted empty model usage"
fi

cat > "$fake_bin/claude" <<'LOOKALIKE_MODEL'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"lookalike","modelUsage":{"claude-fable-5-lookalike":{"inputTokens":1}}}'
LOOKALIKE_MODEL
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted a lookalike model identifier"
fi

cat > "$fake_bin/claude" <<'EMPTY_FABLE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"empty-fable","modelUsage":{"claude-fable-5":{}}}'
EMPTY_FABLE_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted an empty concrete Fable usage record"
fi

cat > "$fake_bin/claude" <<'ZERO_FABLE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"zero-fable","modelUsage":{"claude-fable-5":{"inputTokens":0,"outputTokens":0,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}}'
ZERO_FABLE_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted a zero-token concrete Fable usage record"
fi

cat > "$fake_bin/claude" <<'STRING_FABLE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"string-fable","modelUsage":{"claude-fable-5":{"inputTokens":"0","outputTokens":"0","cacheReadInputTokens":"0","cacheCreationInputTokens":"0"}}}'
STRING_FABLE_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted string token counts"
fi

cat > "$fake_bin/claude" <<'ARRAY_FABLE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"array-fable","modelUsage":{"claude-fable-5":{"inputTokens":[],"outputTokens":[],"cacheReadInputTokens":[],"cacheCreationInputTokens":[]}}}'
ARRAY_FABLE_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted array token counts"
fi

cat > "$fake_bin/claude" <<'NEGATIVE_FABLE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"negative-fable","modelUsage":{"claude-fable-5":{"inputTokens":-1,"outputTokens":2}}}'
NEGATIVE_FABLE_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted a negative token count"
fi

cat > "$fake_bin/claude" <<'BOOLEAN_FABLE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"boolean-fable","modelUsage":{"claude-fable-5":{"inputTokens":false,"outputTokens":2}}}'
BOOLEAN_FABLE_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted a boolean token count"
fi

cat > "$fake_bin/claude" <<'NULL_FABLE_USAGE'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"result":"null-fable","modelUsage":{"claude-fable-5":{"inputTokens":null,"outputTokens":2}}}'
NULL_FABLE_USAGE
chmod +x "$fake_bin/claude"
if FAKE_CLAUDE_ARGS="$fake_args" PATH="$fake_bin:$PATH" sh "$fable_runner" --mode review --workdir "$repo_dir" --prompt-file "$prompt_file" >/dev/null 2>&1; then
  fail "Fable runner accepted a null token count"
fi
pass "Fable implement/review flags and exact positive model-proof refusal matrix"

for document in "$skill" "$contracts"; do
  grep -Fq 'agent_type: sol_advisor_luna_implementer' "$document" || fail "missing Luna spawn in $document"
  grep -Fq 'agent_type: sol_advisor_terra_implementer' "$document" || fail "missing Terra spawn in $document"
  grep -Fq 'agent_type: sol_advisor_sol_reviewer' "$document" || fail "missing Sol spawn in $document"
  grep -Fq 'fork_turns: none' "$document" || fail "missing fresh context in $document"
  if grep -Eq '^[[:space:]]*(model|reasoning_effort):' "$document"; then fail "per-spawn override remains in $document"; fi
done
# Literal Markdown backticks are intentional in this documentation assertion.
# shellcheck disable=SC2016
grep -Fq 'efforts are exactly `high`, `xhigh`, `max`, and `ultra`' "$skill" || fail "primary Sol at-least-High gate is missing"
grep -Fq 'If either field is omitted' "$skill" || fail "primary Sol partial-metadata refusal is missing"
grep -Fq 'effort falls outside that four-value set' "$skill" || fail "primary Sol exact effort-membership gate is missing"
grep -Fq 'Luna / Max' "$skill" || fail "Luna / Max routing is missing"
grep -Fq 'Terra / Max' "$skill" || fail "Terra / Max routing is missing"
grep -Fq '../../scripts/run-fable-agent.sh' "$skill" || fail "Fable runner is not resolved relatively"
grep -Fq 'Fable is an alternate writer, not an extra implementation hop' "$skill" || fail "Fable non-compulsory implementation rule is missing"
grep -Fq 'This is advisory and cross-model-family' "$contracts" || fail "Fable adversarial role is not advisory"
grep -Fq 'Never waive the final Sol review' "$skill" || fail "mandatory Sol review gate is missing"
pass "routing contracts, primary effort gate, and optional Fable policy"

sh -n "$installer"
sh -n "$runtime_inspector"
sh -n "$fable_runner"
sh -n "$script_dir/verify.sh"
pass "shell syntax"

printf '%s\n' "VERIFY PASSED: Sol Advisor v0.4.0 checks completed in $tmp_dir"
