# herdr config

My [herdr](https://herdr.dev) setup: keybindings, popups, and `hq`, a launcher for agent workspaces.

## Install on a new machine

```bash
curl -fsSL https://herdr.dev/install.sh | sh        # if herdr is not installed
git clone <this repo> ~/.config/herdr
~/.config/herdr/bin/bootstrap
```

`bootstrap` links `hq` into `~/.local/bin` and installs herdr integrations for the agent CLIs it finds (claude, omp, copilot, cursor-agent). It is safe to re-run after installing another CLI. Logins stay manual: `cursor-agent login`, and `/login` inside `copilot`.

## hq

Run inside a herdr pane.

| Command | What you get |
| --- | --- |
| `hq code <dir> [label]` | claude, omp, copilot, cursor in a 2×2 grid, plus a shell tab |
| `hq docs <dir> [label]` | claude drafting next to a shell, omp reviewing in its own tab |
| `hq team <dir> "<brief>" [label]` | manager-driven pipeline: spec → review → per-task implement / runtime check / review → final pass, stopping for you at the spec and at sign-off |
| `hq team --resume <dir> [label]` | rebuild the team for an existing `.hq/` |
| `hq respawn <label>-<role>` | fresh session for a crew agent |
| `hq new` | interactive picker (`ctrl+alt+n`) |

### Per-project settings for `hq team`

Optional `.hq/runtime` in the project (the manager writes one if missing):

```
dev=npm run dev
health=http://localhost:3000/health
errors=(Error|Exception|Traceback|ECONNREFUSED|panic)
test=npm test
log_max=20M
autonomy=ask          # trusted = crew agents auto-approve, only on hq/* branches
kind_impl=claude      # swap a role's tool (planner, specrev, impl, taskrev)
```

Roles live in `roles/`. The design is in `docs/specs/`, and the build plan in `docs/plans/`.

## Tests

```bash
bash tests/run.sh
```

These run offline against a fake `herdr` (`tests/fake-herdr/`). `tests/live_team_layout.sh` checks the layout against a real herdr session.
