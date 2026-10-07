# GitHub Copilot CLI

Verified on 2026-10-07 with GitHub Copilot CLI 1.0.93 on macOS, as a primary harness only.

## Operating facts

| Fact | Value |
|---|---|
| Role | Primary firstmate session only; never a crewmate, scout, or secondmate. |
| Worker launch | None; `../../../bin/fm-spawn.sh` has no copilot launch template and refuses it with an actionable message, so `config/crew-harness` and `config/secondmate-harness` must name a verified worker harness such as `claude`. |
| Environment marker | `COPILOT_CLI=1` on tool subprocesses, alongside `COPILOT_AGENT_SESSION_ID` and `COPILOT_CLI_BINARY_VERSION`; a structural ancestor of another harness still outranks it. |
| Process identity | The npm package's node launcher runs a native per-platform binary whose process name is exactly `copilot`; `../../../bin/fm-harness.sh` and `../../../bin/fm-session-lock-lib.sh` match that anchored name, and that binary's pid is the session lock anchor. |
| Supervision | `docs/supervision-protocols/copilot.md`: the arm runs as Copilot's tracked async `bash` command, never detached, and Copilot notifies the session when it exits. |
| Hooks | Copilot loads this repo's `.claude/settings.json` PreToolUse hooks, so the arm and cd seatbelts are active; no Firstmate turn-end guard is verified for Copilot. |
| Session start | Nudge tier: Copilot reads `AGENTS.md`, so the session runs `bin/fm-session-start.sh` itself. |
