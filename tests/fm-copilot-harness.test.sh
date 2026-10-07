#!/usr/bin/env bash
# tests/fm-copilot-harness.test.sh - the portable regression for GitHub Copilot
# CLI as a PRIMARY harness: detection, session-lock identity, the rendered
# supervision protocol, and the refusal to dispatch copilot as a worker.
#
# Copilot's identity checks are HARNESS-DEPENDENT: the verdicts come from what
# the vendor emits (a process name and a tool-subprocess marker). This suite
# pins the LOGIC with real named processes so CI enforces it with no copilot
# installed; docs/verification/copilot.md records the live evidence.
#
# The load-bearing contracts:
#   1. COPILOT_CLI=1 names copilot, and the anchored process name `copilot` is
#      the ancestry evidence; copilotd and github-copilot never identify.
#   2. A structural claude ancestor still outranks a retained COPILOT_CLI, so a
#      claude worker spawned from a copilot primary stays claude.
#   3. The session lock accepts the exact copilot name and rejects decoys.
#   4. The supervision renderer emits the copilot async-bash protocol.
#   5. fm-spawn refuses copilot as a worker harness with an actionable message.
#   6. A worker launched from a copilot primary has the inherited COPILOT_CLI
#      cleared by the launch command fm-spawn types into its pane.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"
# shellcheck source=bin/fm-session-lock-lib.sh
. "$ROOT/bin/fm-session-lock-lib.sh"

HARNESS="$ROOT/bin/fm-harness.sh"
TMP_ROOT=$(fm_test_tmproot fm-copilot-harness)

# Symlinks to the system shell, so `ps -o comm=` reports the link name on macOS
# and the exec name on Linux. Each -c body ends in a no-op so bash does not
# exec-optimize the command away and replace the named process.
make_named_shells() {  # <dir> -> echoes <dir>
  local dir=$1 name
  mkdir -p "$dir"
  for name in copilot copilotd github-copilot claude; do
    ln -sf /bin/bash "$dir/$name"
  done
  printf '%s' "$dir"
}

clean_env() {
  env -u CLAUDECODE -u COPILOT_CLI -u FM_OMP_HARNESS -u PI_CODING_AGENT \
    -u CURSOR_AGENT -u CURSOR_INVOKED_AS -u GEMINI_CLI -u GROK_AGENT \
    -u ATLASSIAN_AGENT_TYPE -u ROVODEV_CLI "$@"
}

test_detection() {
  local bin out decoy
  bin=$(make_named_shells "$TMP_ROOT/named")
  # shellcheck disable=SC2016 # the quoted body expands inside the named shell
  out=$(clean_env "$bin/copilot" -c '"$1"; :' _ "$HARNESS")
  [ "$out" = copilot ] || fail "a process named copilot must detect as copilot, got '$out'"
  for decoy in copilotd github-copilot; do
    # shellcheck disable=SC2016 # the quoted body expands inside the named shell
    out=$(clean_env "$bin/$decoy" -c '"$1"; :' _ "$HARNESS")
    [ "$out" != copilot ] || fail "'$decoy' merely contains copilot and must not detect as copilot"
  done
  # shellcheck disable=SC2016 # the quoted body expands inside the named shell
  out=$(clean_env CLAUDECODE=1 "$bin/copilot" -c '"$1"; :' _ "$HARNESS")
  [ "$out" = copilot ] || fail "a copilot ancestor must outrank an inherited CLAUDECODE, got '$out'"
  # shellcheck disable=SC2016 # the quoted body expands inside the named shell
  out=$(clean_env COPILOT_CLI=1 CLAUDECODE=1 "$bin/claude" -c '"$1"; :' _ "$HARNESS")
  [ "$out" = claude ] || fail "a retained COPILOT_CLI must not relabel a claude worker, got '$out'"
  pass "fm-harness: copilot detects by marker and anchored name; a claude ancestor still wins"
}

test_lock_identity() {
  fm_harness_process_matches copilot '' || fail "session-lock identity must accept the exact copilot name"
  fm_harness_process_matches \
    /usr/lib/node_modules/@github/copilot/node_modules/@github/copilot-linux-x64/copilot '' \
    || fail "session-lock identity must accept the copilot native binary path"
  ! fm_harness_process_matches copilotd '' || fail "session-lock identity must not accept copilotd"
  ! fm_harness_process_matches github-copilot '' || fail "session-lock identity must not accept github-copilot"
  pass "session lock: copilot is anchored, decoys stay out"
}

test_supervision_render() {
  local home out
  home="$TMP_ROOT/render-home"
  mkdir -p "$home/state" "$home/config" "$home/data"
  out=$(FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" FM_CONFIG_OVERRIDE="$home/config" \
    FM_DATA_OVERRIDE="$home/data" "$ROOT/bin/fm-supervision-instructions.sh" --harness copilot 2>&1)
  assert_contains "$out" "primary harness: copilot" "renderer did not keep the copilot harness"
  assert_contains "$out" "GitHub Copilot CLI async-bash supervision" "renderer did not emit the copilot protocol"
  assert_contains "$out" 'exec bin/fm-watch-arm.sh' "copilot protocol did not name the arm"
  pass "supervision instructions: copilot renders its async-bash protocol"
}

test_spawn_refuses_copilot_worker() {
  local case_dir home proj wt fakebin id out status
  case_dir="$TMP_ROOT/spawn"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  id="copilot-refuse-x1"
  fakebin=$(make_spawn_fakebin "$case_dir/fake" gh-axi gh)
  fm_test_spawn_home "$home" copilot
  fm_test_spawn_brief "$home" "$id" brief
  fm_git_worktree "$proj" "$wt" "fm/$id"
  out=$(fm_test_run_spawn "$home" "$wt" "$fakebin" "$id" "$proj" --mode no-mistakes --yolo off)
  status=$?
  [ "$status" -ne 0 ] || fail "spawn must refuse a copilot crew harness"
  assert_contains "$out" "copilot is verified as a primary harness only" "crew refusal was not actionable: $out"
  out=$(fm_test_run_spawn "$home" "$wt" "$fakebin" "$id" "$proj" copilot --mode no-mistakes --yolo off)
  status=$?
  [ "$status" -ne 0 ] || fail "spawn must refuse an explicit copilot harness"
  assert_contains "$out" "copilot is verified as a primary harness only" "explicit refusal was not actionable: $out"
  pass "fm-spawn: copilot is refused as a worker with an actionable message"
}

test_spawn_clears_copilot_marker() {
  local case_dir home proj wt fakebin id out status launch
  case_dir="$TMP_ROOT/spawn-clear"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  id="copilot-clear-x2"
  fakebin=$(make_spawn_fakebin "$case_dir/fake" gh-axi gh claude)
  fm_test_spawn_home "$home" claude
  fm_test_spawn_brief "$home" "$id" brief
  fm_git_worktree "$proj" "$wt" "fm/$id"
  out=$(COPILOT_CLI=1 FM_FAKE_LAUNCH_LOG="$case_dir/launch.log" \
    fm_test_run_spawn "$home" "$wt" "$fakebin" "$id" "$proj" --mode no-mistakes --yolo off)
  status=$?
  [ "$status" -eq 0 ] || fail "claude spawn under a copilot primary should succeed: $out"
  launch=$(cat "$case_dir/launch.log")
  assert_contains "$launch" "-u COPILOT_CLI" "worker launch must clear the inherited copilot marker: $launch"
  pass "fm-spawn: a worker launch clears the inherited COPILOT_CLI marker"
}

test_detection
test_lock_identity
test_supervision_render
test_spawn_refuses_copilot_worker
test_spawn_clears_copilot_marker
