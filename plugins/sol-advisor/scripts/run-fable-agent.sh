#!/bin/sh
# Run an optional Claude Fable 5 implementation or adversarial-review lane.

set -eu

usage() {
  cat <<'EOF'
Usage: run-fable-agent.sh --mode implement|review --workdir PATH --prompt-file PATH [--max-budget-usd AMOUNT]

Runs Claude Code non-interactively with the Fable alias at max effort. The implement
mode can edit its explicitly owned files. The review mode is advisory, auto-denies
permission prompts, and is not allowed Edit, Write, or Bash tools. Both modes use
Claude Code safe mode, so the supplied contract must include every relevant repository
rule. JSON output is written to stdout so the Sol parent can inspect model usage,
result, and cost metadata.
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

mode=''
workdir=''
prompt_file=''
max_budget_usd=''
max_budget_set=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      [ "$#" -ge 2 ] || fail "--mode requires implement or review."
      mode=$2
      shift 2
      ;;
    --workdir)
      [ "$#" -ge 2 ] || fail "--workdir requires a path."
      workdir=$2
      shift 2
      ;;
    --prompt-file)
      [ "$#" -ge 2 ] || fail "--prompt-file requires a path."
      prompt_file=$2
      shift 2
      ;;
    --max-budget-usd)
      [ "$#" -ge 2 ] || fail "--max-budget-usd requires an amount."
      max_budget_usd=$2
      max_budget_set=1
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *) fail "unknown argument: $1 (run with --help for usage)." ;;
  esac
done

case "$mode" in implement|review) ;; *) fail "--mode must be implement or review." ;; esac
[ -n "$workdir" ] || fail "--workdir is required."
[ -n "$prompt_file" ] || fail "--prompt-file is required."
command -v claude >/dev/null 2>&1 || fail "Claude Code is not installed or not on PATH."
command -v jq >/dev/null 2>&1 || fail "jq is required to validate Claude Code JSON output."

case "$workdir" in
  /*) ;;
  *) workdir=$(pwd -P)/$workdir ;;
esac
[ -d "$workdir" ] && [ ! -L "$workdir" ] || fail "workdir is not a real directory: $workdir"
case "$workdir" in /|//) fail "refusing to run an implementation agent at the filesystem root." ;; esac

case "$prompt_file" in
  /*) ;;
  *) prompt_file=$(pwd -P)/$prompt_file ;;
esac
[ -f "$prompt_file" ] && [ ! -L "$prompt_file" ] || fail "prompt file is not a regular file: $prompt_file"
[ -s "$prompt_file" ] || fail "prompt file is empty: $prompt_file"

if [ "$max_budget_set" -eq 1 ]; then
  if ! jq -en --arg amount "$max_budget_usd" '
    ($amount | test("\\A(0|[1-9][0-9]*)(\\.[0-9]+)?\\z"))
    and (($amount | tonumber) > 0)
  ' >/dev/null; then
    fail "--max-budget-usd must be a canonical decimal amount greater than zero."
  fi
fi

case "$mode" in
  implement)
    permission_mode=acceptEdits
    allowed_tools=Read,Edit,Write,Bash,Grep,Glob
    role_prompt="Act as Sol Advisor's optional Fable implementation specialist. Work only within the supplied five-part specification and exact file ownership. Preserve concurrent edits, do not broaden architecture, run the stated verification, and return concrete evidence. Surface ambiguity instead of guessing."
    ;;
  review)
    permission_mode=dontAsk
    allowed_tools=Read,Grep,Glob
    role_prompt="Act as Sol Advisor's optional cross-family adversarial reviewer. Remain strictly read-only. Do not edit files, run shell commands, or implement fixes. Inspect the supplied goal, diff, evidence, and readable files. Return only evidence-backed findings and a verdict of pass, concerns, or block. This advice does not replace the mandatory fresh Sol review."
    ;;
esac

set -- claude -p \
  --safe-mode \
  --model fable \
  --effort max \
  --permission-mode "$permission_mode" \
  --tools "$allowed_tools" \
  --append-system-prompt "$role_prompt" \
  --no-chrome \
  --no-session-persistence \
  --output-format json

if [ "$max_budget_set" -eq 1 ]; then
  set -- "$@" --max-budget-usd "$max_budget_usd"
fi

output_file=$(mktemp "${TMPDIR:-/tmp}/sol-advisor-fable.XXXXXX") || fail "could not create output file."
cleanup() {
  if [ -n "${output_file-}" ] && [ -f "$output_file" ]; then
    rm -f "$output_file"
  fi
}
trap cleanup 0 HUP INT TERM

if ! (cd "$workdir" && "$@" < "$prompt_file" > "$output_file"); then
  cat "$output_file"
  fail "Claude Fable lane failed."
fi

jq empty "$output_file" || {
  cat "$output_file"
  fail "Claude Code did not return valid JSON."
}

if ! jq -se '
  length == 1
  and (
    .[0] as $root
    | ($root | type) == "object"
      and (
        ($root | has("modelUsage")) as $camel
        | ($root | has("model_usage")) as $snake
        | ($camel != $snake)
          and (
            (if $camel then $root.modelUsage else $root.model_usage end) as $usage
            | ($usage | type) == "object"
              and ($usage | keys) == ["claude-fable-5"]
              and ($usage["claude-fable-5"] | type == "object")
              and (
                $usage["claude-fable-5"] as $record
                | [
                    (if ($record | has("inputTokens")) then $record.inputTokens else empty end),
                    (if ($record | has("input_tokens")) then $record.input_tokens else empty end),
                    (if ($record | has("outputTokens")) then $record.outputTokens else empty end),
                    (if ($record | has("output_tokens")) then $record.output_tokens else empty end),
                    (if ($record | has("cacheReadInputTokens")) then $record.cacheReadInputTokens else empty end),
                    (if ($record | has("cache_read_input_tokens")) then $record.cache_read_input_tokens else empty end),
                    (if ($record | has("cacheCreationInputTokens")) then $record.cacheCreationInputTokens else empty end),
                    (if ($record | has("cache_creation_input_tokens")) then $record.cache_creation_input_tokens else empty end)
                  ] as $tokens
                | ($tokens | length) > 0
                  and all($tokens[]; (type == "number" and . >= 0))
                  and any($tokens[]; . > 0)
              )
          )
      )
  )
' "$output_file" >/dev/null; then
  cat "$output_file"
  fail "Claude Code output did not prove exclusive, positive usage of concrete model claude-fable-5."
fi

cat "$output_file"
