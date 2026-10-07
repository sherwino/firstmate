# GitHub Copilot CLI primary verification

Verified on 2026-10-07 with GitHub Copilot CLI 1.0.93 on macOS (darwin-arm64), from a live interactive Copilot session in a Firstmate home.

## Identity and session lock

Observed ancestry from a Copilot tool subprocess: `bash` -> `copilot` (the native `@github/copilot-darwin-arm64/copilot` binary) -> `node` (the npm launcher) -> login shell.
The tool subprocess environment carried `COPILOT_CLI=1`, `COPILOT_AGENT_SESSION_ID`, and `COPILOT_CLI_BINARY_VERSION=1.0.93`.

```text
$ bash bin/fm-harness.sh
copilot
$ bash bin/fm-harness.sh ancestry
comm copilot
$ env -u COPILOT_CLI bash bin/fm-harness.sh
copilot
$ bash -c '. bin/fm-session-lock-lib.sh; fm_harness_ancestry_pids'
<pid of the copilot binary>
```

Before this change the same session printed `unknown` and session start refused the fleet lock with `cannot locate harness process in ancestry`.

## Supervision wake

A watcher was armed in a throwaway lab home through Copilot's `bash` tool in `mode: "async"`, without `detach`.
The arm printed `watcher: started pid=<N> (beacon fresh)` and stayed alive across later tool calls.
Appending a status line in the lab home made the arm exit 0 with `signal: <lab>/state/labtask.status`, which Copilot surfaced as a completed async command.
The rendered arm command passes `bin/fm-arm-pretool-check.sh`, and Copilot loads the repository's `.claude/settings.json` PreToolUse hooks, so the arm and cd seatbelts run.

## Not verified

- Copilot as a crewmate, scout, or secondmate; `bin/fm-spawn.sh` refuses it.
- A Firstmate turn-end guard for Copilot.
- A Copilot session-open hook; [`sessionstart-nudge.md`](../sessionstart-nudge.md#copilot-cli) records the surface as uncovered.
- Process identity on Linux or Windows builds of Copilot CLI.

`tests/fm-copilot-harness.test.sh` pins the identity, lock, rendering, and worker-refusal logic portably.
Run it outside a live Copilot session, because a real `copilot` ancestor correctly outranks the decoy processes it builds.
