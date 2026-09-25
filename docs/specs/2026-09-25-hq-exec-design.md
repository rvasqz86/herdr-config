# hq exec — a management team for a startup

Date: 2026-09-25. Status: approved in conversation, awaiting written review.

## Goal

`hq exec` opens a management team (CEO, COO, CTO) for a startup that lives in a directory. You bring
questions to the CEO. The execs write positions, the CEO decides, and every decision is filed as a
memo in the company's own git history. The CEO decides alone except for decisions that touch money
above a limit, people, or customers, which wait for the founder.

Like `hq team`, it works on any folder: if the company documents are missing, the team creates
them, starting with an interview.

This is piece 1 of 3. Piece 2 adds a recurring management meeting and company metrics. Piece 3 lets
the CTO start `hq team` for build work and the COO track it. Both build on the files below.

## Command

```
hq exec <dir> ["<question>"] [label]   open the team for the startup in <dir>; the question, if given, goes to the CEO
hq exec --resume <dir> [label]   rebuild after a restart; the CEO reports where things stand
hq new → exec                    picker; asks for a folder, then an optional first question
```

The label defaults to the folder name. Agents are named `<label>-ceo`, `<label>-cto`, `<label>-coo`,
and `team_names_free` refuses a label already in use.

`<dir>` must exist. If it is not a git repository, `hq exec` runs `git init -b main` in it so the
company documents get history from the first commit. A dirty tree is allowed (this is the founder's
folder, not a build branch).

The second positional argument is always the first question (use "" to give a label without a question). It is passed verbatim to the CEO's first prompt, never executed (same handling as the hq team brief).

## Layout

Workspace `<label>`, two tabs, every pane labelled:

```
exec tab                                      shell tab
┌────────────────────────┬─────────────┐      ┌──────────────────┐
│ <label>-ceo            │ <label>-cto │      │ shell            │
│                        ├─────────────┤      │                  │
│                        │ <label>-coo │      │                  │
└────────────────────────┴─────────────┘      └──────────────────┘
```

The CEO pane is the left 60% of the exec tab (`pane split --direction right --ratio 0.6`). CTO and
COO stack in the right column.

## Roles

| Role | Default tool | Job |
| --- | --- | --- |
| ceo | claude | Talks to the founder, frames each question, briefs the others, decides, writes the memo, escalates money, people and customer decisions |
| cto | omp | Technical position: feasibility, architecture, build cost and risk. Reads the code if the folder holds any. |
| coo | copilot | Operating position: money, time, process, customers, delivery risk |

Tool resolution, first match wins: `HQ_KIND_<role>` in the environment, `kind_<role>` in
`company/settings`, `kind_<role>` in `hq.local`, the default. `kind_for` gains a second config
file: it takes the project-level file path from the caller (`.hq/runtime` for team roles,
`company/settings` for exec roles).

All three agents start with `--add-dir <roles dir>` so they can read their role files (same as
`hq team`). No agent gets auto-approve flags; there is no `autonomy` setting in this piece.

The CEO is long-lived. The CTO and COO are respawned before every decision so each position starts
from the files, not from a stale conversation.

Startup handling is shared with `hq team`: start every agent, wait for startup screens
(`await_ready`), prime the crew with their role files, then prime the CEO. Unprimed agents are
listed at the end.

## Files

Everything lives in `company/` inside `<dir>`, visible and committed.

```
company/
  settings              spend_limit=100, escalate=money people customers, kind_<role>=…
  brief.md              product, customers, stage, revenue/runway, team, 90-day goals, constraints
  tech.md               CTO: stack, technical state, what exists, what is risky
  ops.md                COO: costs, revenue, runway, customers, how things run, open questions
  decisions/
    log.md              one line per decision: NNNN · date · title · status
    NNNN-<slug>.md      decision memo
  positions/
    NNNN-cto.md         CTO position for decision NNNN
    NNNN-coo.md         COO position for decision NNNN
```

`settings` format is the `key=value` format of `.hq/runtime` (comments after `#`, last value wins).
Defaults when a key is missing: `spend_limit=100`, `escalate=money people customers`.

### Decision memo, `decisions/NNNN-<slug>.md`

```
# NNNN <title>
Date · Status: in progress | awaiting founder | decided | rejected
Escalation: none | money | people | customers   (one or more)

## Question        as asked, verbatim
## Context         what the CEO found in company/ and earlier decisions
## Options         the options considered
## Positions       one line each: CTO, COO (links to positions/)
## Decision
## Rationale
## Risks accepted
## Next steps      - [ ] <step> — owner: cto|coo|ceo|founder — by <date>
## Founder         approve / reject + reason / changes requested   (only when escalated)
```

### Position, `positions/NNNN-<role>.md`

```
# NNNN <title> — <role> position
Recommendation:
Reasoning:
Risks:
Needs:            what it would take (time, money, people, tech)
Confidence:       low | medium | high, and why
```

## First session

If `company/brief.md` is missing, the CEO:

1. Interviews the founder in its pane, one question at a time: product, who pays, stage, revenue
   and runway, team, next-90-day goals, constraints. Stops when it can fill `brief.md`.
2. Writes `company/settings` (defaults) if missing, and `brief.md`.
3. Prompts the CTO: write `tech.md` from the code and docs in `<dir>` (say "no code yet" if none)
   and the brief. Prompts the COO: write `ops.md` from the brief, listing unknowns under
   `## Open questions`. Both in parallel, 15-minute budget.
4. Reads both, asks the founder the open questions it can't answer, and commits everything as
   `exec: company baseline`.

If `brief.md` exists, the CEO reads `brief.md`, `tech.md`, `ops.md`, `settings` and
`decisions/log.md` at the start of every session and says in two lines where the company stands.

## A decision

The founder types a question into the CEO pane. The CEO:

1. **Frame.** Creates `decisions/NNNN-<slug>.md` (NNNN = last number in `log.md` + 1) with
   Question, Context, Options, `Status: in progress`, and the Escalation classification:
   - `money` when a real option commits more than `spend_limit`
   - `people` when an option hires, fires or changes anyone's role, including contractors
   - `customers` when an option changes price, terms, or anything customers will notice
   Appends the line to `log.md` now, so a crash leaves a trace.
2. **Brief both execs at once.** `hq respawn <label>-cto` and `hq respawn <label>-coo`, then
   `herdr agent prompt` each without `--wait`: "Write your position on decision NNNN to
   `company/positions/NNNN-<role>.md`. When finished reply exactly DONE <path> or BLOCKED: <reason>."
   Then `herdr agent wait` each, in 9-minute slices, budget 10 minutes per exec.
3. **Resolve.** Reads both positions. If they conflict or leave a gap, asks that exec one
   follow-up, at most one per exec per decision, via `agent prompt --wait`.
4. **Write the memo.** Fills Positions, Decision, Rationale, Risks accepted, Next steps (each with
   an owner and a date).
5. **Escalate or file.**
   - Escalation `none`: `Status: decided`. Posts a five-line summary in its pane.
   - Otherwise: `Status: awaiting founder`, `herdr notification show "Decision NNNN needs you"
     --body "<title>: <escalation>" --sound request`, posts the memo summary and asks for
     `approve`, `reject`, or changes. `approve` → decided. `reject` → rejected, with the founder's
     reason under `## Founder`. Changes → recorded under `## Founder`, back to step 3.
6. **Log and commit.** Updates the `log.md` line's status, `git add company && git commit -m
   "exec: NNNN <title>"`.

Questions that are not decisions ("what is our biggest risk?") are answered from the files without
the loop, and the CEO says it is not filing a decision.

Rules the CEO follows, from `roles/manager.md`: never answer another agent's permission prompt
(notify the founder instead), never re-send a prompt after a timeout without reading the pane, never
edit code, never kill processes it did not start. Its Bash calls fit the 10-minute tool limit, so
waits run in 9-minute slices.

The CTO and COO write only under `company/positions/` and, on the first session, `company/tech.md`
or `company/ops.md`. They reply `DONE <path>` or `BLOCKED: <reason>`.

## Recovery

- `hq respawn <label>-cto|coo`: as for team crew. `respawn` learns the exec roles; `ceo` is refused
  like `manager` ("use hq exec --resume").
- `hq exec --resume <dir> [label]`: requires `company/brief.md`; rebuilds the workspace and starts
  the CEO in resume mode. The CEO reports the company state and any memo left `in progress` or
  `awaiting founder`, and offers to continue it.
- Startup screens, "not primed", labels: shared `hq` code.

## Changes to `hq`

- `role_kind`: `ceo` → claude, `cto` → omp, `coo` → copilot. `role_file` maps them to
  `roles/ceo.md`, `roles/cto.md`, `roles/coo.md`.
- `kind_for dir role`: reads `kind_<role>` from `<dir>/company/settings` for exec roles and from
  `<dir>/.hq/runtime` for team roles (a small `role_conf` helper picks the file by role).
- `start_role`: unchanged apart from the wider role list; exec roles get `--add-dir` and no
  autonomy flags.
- `layout_exec dir label mode question`, `cmd_exec`, `exec` in `run`/picker.
- `cmd_respawn`: accepts cto/coo, refuses ceo.
- `hq.local.example` and README gain `kind_ceo|cto|coo`.

## Tests (fake herdr)

`tests/test_exec.sh`:
- layout: workspace, tabs `exec` and `shell`, ratio 0.6 split, labels `<label>-ceo|cto|coo` and
  `shell`, three starts with the right kinds and `--add-dir <roles>`, four prompts (cto, coo, ceo
  primed; CEO prompt includes the first question verbatim, canary not executed).
- tools: `kind_cto=claude` in `company/settings` and in `hq.local`, env override, bad kind exits 1
  before any layout.
- `git init` on a plain folder; an existing repo untouched.
- `--resume` without `company/brief.md` exits 1 with a message; with it, the CEO prompt says
  `Mode: resume`.
- `hq respawn x-cto` works; `hq respawn x-ceo` refused.
- label already in use refused.

`tests/test_roles.sh`: the three new role files exist and name their files and the reply protocol;
`ceo.md` mentions `spend_limit`, `awaiting founder`, `exec: company baseline`.

## Docs

README: `hq exec` row in the commands table, a `company/settings` section, the three new
`kind_` keys. How-to guide: a "Run your startup with hq exec" section (command, layout, first
session, a decision, escalation, recovery).

## Out of scope

Weekly cadence and metrics (piece 2). CTO starting `hq team` and COO tracking it (piece 3).
Round-table debate (option B). `autonomy=trusted` for exec roles.
