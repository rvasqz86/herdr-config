# hq team — manager-driven multi-agent pipeline

Date: 2026-09-23
Status: approved in conversation, pending written review

## Goal

One command turns a feature brief into a reviewed, architecturally coherent
branch. A manager agent drives a crew of role agents through
spec → spec review → per-task implement/check/review → final pass, inside herdr,
stopping for the human at two gates.

Success: on a real repo, `hq team <repo> "<brief>"` produces a branch with one
commit per task, every task reviewed PASS with a clean runtime check, and a
summary the human signs off — with the human only touching Gate 1, Gate 2, and
(unless trusted) permission prompts.

Non-goals: parallel task execution, worktrees, agents talking to each other
directly, a log-watching LLM agent, browser/UI QA (possible later as an
optional role).

## Commands

| Command | Does |
| --- | --- |
| `hq team <dir> "<brief>" [label]` | Build the team layout, start all roles, hand the brief to the manager |
| `hq team --resume <dir> [label]` | Rebuild the layout for an existing `.hq/`, manager continues from `.hq/state` |

`<label>` defaults to the directory name; agent names are `<label>-<role>`.

## Layout

Workspace `<label>`, two tabs:

```
tab "manager"                         tab "crew"
┌──────────────────┬─────────┐        ┌──────────────┬──────────────┐
│ manager (claude) │ shell   │        │ planner (omp)│ specrev      │
│                  │ (human) │        │              │ (copilot)    │
│                  │         │        ├──────────────┼──────────────┤
│                  │         │        │ impl (cursor)│ taskrev      │
│                  │         │        │              │ (claude)     │
└──────────────────┴─────────┘        ├──────────────┴──────────────┤
                                      │ runtime (plain shell)       │
                                      └─────────────────────────────┘
```

## Roles

| Role | Agent name | Tool | May write | Commits |
| --- | --- | --- | --- | --- |
| manager | `<label>-manager` | claude | `.hq/**` | yes, one per task |
| planner | `<label>-planner` | omp | `.hq/spec.md`, `.hq/tasks/**` | no |
| spec reviewer | `<label>-specrev` | copilot | `.hq/spec-review.md` | no |
| implementer | `<label>-impl` | cursor | source + tests, task file's "Spec issue" section | no |
| task reviewer | `<label>-taskrev` | claude | `.hq/reviews/**` | no |
| runtime | pane only | — | — | — |

Each role's instructions live in `~/.config/herdr/roles/<role>.md`, sent as the
agent's first prompt (uniform across tools). The manager's role file includes
the herdr commands it needs (`agent prompt/wait/read`, `pane run/read/wait-output`,
`notification show`, `agent start`).

Crew agents only talk to the manager. Every crew prompt ends with the contract:
write output to the named file, then reply exactly `DONE <path>` or
`BLOCKED: <reason>`. The manager reads files, not terminal scrollback.

## Shared state (`.hq/` in the repo, committed on the feature branch)

```
brief.md          the human's request
architecture.md   baseline the manager judges against
runtime           key=value: dev, health, errors, test, autonomy
spec.md           goals, non-goals, design, interfaces, data, risks, test plan
spec-review.md    reviewer findings per round
tasks/NN-slug.md  goal, files, acceptance criteria, Status:, Spec issue:
reviews/NN.md     per round: runtime findings + code review verdict PASS|FIX
log.md            manager's decisions, append-only
state             phase=…, task=NN, round=N
summary.md        final report for Gate 2
```

`.hq/runtime` example:

```
dev=npm run dev
health=http://localhost:3000/health
errors=(Error|Exception|Traceback|ECONNREFUSED|panic)
test=npm test
log_max=20M         # runtime log cap (see below)
kind_impl=claude    # optional per-role tool override (also env HQ_KIND_<role>)
autonomy=ask        # or: trusted
```

The runtime pane runs `<dev> 2>&1 | hq runlog .hq/runtime.log <log_max>`: the full
server output (not only errors), cleared on each restart, rotated to
`.hq/runtime.log.1` at half of `log_max` so both files together stay about
`log_max`. Both are gitignored. Reviews get only matching error lines with
context; a rotation is reported as "log trimmed".

## Flow

**A. Setup (manager)**
1. Refuse to start on a dirty working tree; create branch `hq/<slug>`.
2. Write `brief.md`. Build `architecture.md` from CLAUDE.md, `docs/architecture*`,
   ADRs; if none exist, draft it from the code and mark it `DRAFT`.
3. Write/confirm `runtime` (inferred from package.json, Makefile, etc. if absent).
4. Start the dev server in the runtime pane; record the clean-startup log.

**B. Spec**
1. Planner writes `spec.md` + `tasks/NN-*.md` (each task = one reviewable commit).
2. Spec reviewer writes `spec-review.md`.
3. Manager checks the spec against `architecture.md`, adds findings.
4. Planner revises. Max 2 rounds; leftovers become open questions.

**Gate 1 (human)** — notification with sound + summary in the manager pane:
spec highlights, task list, open questions, runtime config, baseline if DRAFT.
Human replies `approve` or gives changes (→ back to B). No code before this.

**C. Task loop** (sequential, per task)
1. Fresh implementer session; implementer builds the task, runs tests, replies `DONE`. No commit.
2. Runtime check: ensure server up, hit `health`, run `test`, grep new server
   output for `errors`. Findings → `reviews/NN.md`.
3. Fresh task-reviewer session; reviews `git diff` vs task, spec, architecture;
   writes PASS/FIX + findings to `reviews/NN.md`.
4. FIX → implementer gets findings, repeat 1–3. Max 3 rounds.
5. PASS (and runtime clean) → manager coherence check against earlier tasks
   (naming, layering, patterns) → commit `task NN: <title>` → update Status, log, state.

**D. Final pass (manager)**: whole-branch review against `architecture.md`;
clean server restart, full `test`, log check; write `summary.md`.

**Gate 2 (human)** — notification + summary. `ship` → `gh pr create`
(default), `merge` → merge locally, or changes → new tasks → C.

## Failure handling

| Situation | Behavior |
| --- | --- |
| Agent blocked on a permission prompt | Manager never answers it; notifies the human with what's pending |
| Stage timeout (spec 20m, impl 30m, reviews 10m) | Read the pane; if still working extend once, else notify. Never re-send blindly |
| 3 FIX rounds on a task | Stop, log blocker, ask human: split / amend spec / take over / skip |
| `BLOCKED: spec issue` | Local fix → manager amends task + logs. Interface/data/architecture change → stop and ask human |
| Dev server won't start / crashes | Runtime finding for the current task |
| Port in use | Tell the human; never kill processes it didn't start |
| Anything crashes | `hq team --resume` rebuilds layout; manager continues from `state` |

## Autonomy

`autonomy=ask` (default): crew agents start normally; approvals go to the human.

`autonomy=trusted` (set per project in `.hq/runtime`): crew agents start with
their auto-approve flags, and only ever on an `hq/*` branch:

| Tool | Flag |
| --- | --- |
| claude | `--dangerously-skip-permissions` |
| omp | `--auto-approve` |
| copilot | `--allow-all-tools` |
| cursor-agent | `--force --trust` |

The manager itself always runs with normal permissions.

## Files to build

```
~/.config/herdr/bin/hq                 add `team`, `--resume`, `respawn`, `runlog`
~/.config/herdr/roles/manager.md
~/.config/herdr/roles/planner.md
~/.config/herdr/roles/spec-review.md
~/.config/herdr/roles/implementer.md
~/.config/herdr/roles/task-review.md
```

The orchestration logic lives in `manager.md`, not in bash. `hq` only builds
the layout, starts agents with the right flags, and sends first prompts.

## Testing

1. Layout test: `hq team` on a scratch repo — 7 panes, correct agent names,
   runtime pane running. Close afterwards.
2. End-to-end on a tiny Express app (`/health`), brief "add GET /time returning
   ISO time, with a test" (~2 tasks). The human answers Gate 1 and Gate 2; Gate 2
   stops at `ship` without a PR (no remote).
3. Fault test: kill the dev server mid-task → runtime finding blocks PASS.

## Verification — 2026-09-23

Run on a scratch node:http fixture (`tests/fixtures/make-time-app.sh`) with
`autonomy=trusted`. Cursor was not logged in and the Copilot account has no
CLI access (omp uses the same Copilot provider), so `.hq/runtime` set
`kind_planner=claude`, `kind_specrev=claude`, `kind_impl=claude`. Claude acted
as the human at both gates at the user's request.

| Check | Result |
| --- | --- |
| Offline suite (`bash tests/run.sh`, fake herdr) | PASS, 5 files |
| Live layout | 7 panes, tabs manager + crew, 5 named agents |
| E2E "GET /time" | spec READY round 1 → Gate 1 approve → task 01 PASS round 1 → Gate 2; `npm test` 3/3, `/time` returns ISO JSON |
| Gate 2 `ship` without a remote | Manager explained, did not push, stayed at gate2 |
| Gate 2 "changes" path | New task 02 (GET /uptime) run through Phase C |
| Fault test | Injected startup `Error: boom` → runtime NOT clean → FIX → round 2 removed it → clean → PASS → commit |

Defects the live runs found, each fixed test-first in `bin/hq`:
1. Role prompts typed into startup screens; Claude's trust dialog defaults to "No, exit", so agents quit. → start all agents, then wait until ready before prompting.
2. herdr reports agents on trust/login screens as idle. → also read the screen for startup markers.
3. Narrow panes soft-wrap dialog text. → match with whitespace removed; any "No, exit" counts.
4. Trusted Claude showed the Bypass Permissions confirmation. → `--settings {"skipDangerousModePermissionPrompt":true}` per process.
5. The manager could not recover an exited crew agent. → crew panes are labelled; `hq respawn` falls back to the label.
6. `hq respawn` raced herdr releasing the old agent (first respawn always failed). → wait for `pane get` to show no agent.

Added: per-role tool override `kind_<role>` in `.hq/runtime` (or env `HQ_KIND_<role>`).
Not verified live: cursor and copilot as crew (not logged in / no access), `ask` autonomy, `hq team --resume`.
