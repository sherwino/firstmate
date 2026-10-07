Mode: GitHub Copilot CLI async-bash supervision.

When this session owns supervision and away mode is not active:
1. Drain first with `bin/fm-wake-drain.sh`.
   After handling all emitted wakes and reconciling open decisions and unread status lines, run the exact `--ack-through` command printed as `WAKE_ACK_REQUIRED`; until then the work remains durable for idempotent re-handling after interruption.
2. Source `__FM_X_MODE_ENV__` first when Relay is active.
3. First cycle: arm with Copilot's tracked async `bash` tool, as its own call:

   `bash` with `mode: "async"` (never `detach: true`) on:
   `[ -f __FM_X_MODE_ENV_SH__ ] && . __FM_X_MODE_ENV_SH__; exec __FM_GROK_ARM__`

4. Read the arm's one-line status with `read_bash` after a short delay, and trust only that line.
5. `watcher: started ...` or `watcher: attached ...` means a live cycle exists.
   On attach, the async command follows verified identity-matched successors instead of exiting when the first cycle ends.
6. Failure or missing cycle only: `watcher: FAILED ...` means supervision is down; fix and re-arm.
7. After a successful start or attach status, end the turn.
   The async arm remains the live wait until it returns an actionable wake or failure.
8. Waiting is silent.
9. Never use shell `&`, `nohup`, or `detach: true` for firstmate supervision.
10. Never bundle the arm onto another command.

Copilot CLI delivers a system notification when the async arm's shell exits.
When that notification arrives for the arm:
1. Run `bin/fm-wake-drain.sh` first.
2. Optionally fetch the arm output with `read_bash` on the arm's shell id for the reason line.
3. Handle `signal`, `stale`, `check`, or `heartbeat` using the harness-neutral contract in `AGENTS.md`.
4. Ordinary wake: re-arm the next cycle with the same async `__FM_GROK_ARM__` call if the home still needs supervision, as `bin/fm-supervision-lib.sh` defines it.
5. Do not invent a wake from an attach-status line alone.
   Drain the queue and act only on real wake records, the drain's `OPEN DECISIONS` and `UNREAD STATUS` entries, or a real watcher reason line.
   Re-arm attaches to an existing healthy cycle when one is already present and follows its verified successor chain.
   See [`watcher-continuity.md`](../watcher-continuity.md) for the arm-layer successor and clean-close failure contract.

Copilot CLI has no verified Firstmate turn-end guard, so the async arm is the only wake path; never end a turn while work is under way without a confirmed live arm.
The async arm is attached to the Copilot session and ends when that session exits, so a restarted session re-arms after its session-start digest.
Copilot is verified as a primary harness only; workers and secondmates need `config/crew-harness` and `config/secondmate-harness` naming a verified worker harness such as `claude`.
