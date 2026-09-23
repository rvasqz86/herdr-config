# herdr config

My [herdr](https://herdr.dev) setup: keybindings, popups, and `hq`, a launcher for agent workspaces.

## Install on a new machine

Works on Linux and macOS (including macOS's built-in bash 3.2). You need `git`, `jq` and [herdr](https://herdr.dev).

1. Install herdr, if it isn't already:

   ```bash
   curl -fsSL https://herdr.dev/install.sh | sh
   ```

2. Clone this repo to `~/.config/herdr`. The repo is private, so sign in first with `gh auth login` (or use an SSH key):

   ```bash
   git clone https://github.com/rvasqz86/herdr-config.git ~/.config/herdr
   ```

   If git says `destination path '~/.config/herdr' already exists`, herdr has already written a default config there. Move it aside and clone again:

   ```bash
   mv ~/.config/herdr ~/.config/herdr.orig
   git clone https://github.com/rvasqz86/herdr-config.git ~/.config/herdr
   ```

3. Run the bootstrap script:

   ```bash
   ~/.config/herdr/bin/bootstrap
   ```

   It links `hq` into `~/.local/bin` and installs herdr integrations for whichever agent CLIs it finds (claude, omp, copilot, cursor-agent). Run it again after you install another CLI.

4. Log in to each agent CLI once: `cursor-agent login`, and `/login` inside `copilot`.

5. If this machine is missing any of claude, omp, copilot or cursor, pick the tools it has in `~/.config/herdr/hq.local`. See [Per-machine tools](#per-machine-tools-hqlocal).

6. Restart herdr (or run `herdr server reload-config`) so it picks up the keybindings, then press `ctrl+alt+n` for the `hq new` picker.

To update later: `git -C ~/.config/herdr pull`.

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

## Per-machine tools (`hq.local`)

By default, `hq` uses these tools:

| Layout / role | Default |
| --- | --- |
| `hq code` | claude, omp, copilot, cursor |
| `hq docs` writer / reviewer | claude / omp |
| `hq team` manager, planner, specrev, impl, taskrev | claude, omp, copilot, cursor, claude |

If a machine doesn't have one of these, say it has no claude, change the choice in that machine's `~/.config/herdr/hq.local`. `bootstrap` creates the file from [`hq.local.example`](hq.local.example), with every line commented out. It isn't in git, so each machine keeps its own and `git pull` never touches it.

Example for a machine without claude:

```
code_tools=omp copilot cursor   # 1 to 4 tools; the grid shrinks to fit
docs_writer=omp
docs_reviewer=copilot
kind_manager=omp
kind_taskrev=copilot
```

Every key:

| Key | Used by | Value |
| --- | --- | --- |
| `code_tools` | `hq code` | 1–4 tools, separated by spaces, filled left-to-right, then top-to-bottom |
| `docs_writer`, `docs_reviewer` | `hq docs` | one tool each |
| `kind_manager`, `kind_planner`, `kind_specrev`, `kind_impl`, `kind_taskrev` | `hq team` | one tool per role |

Tool names: `claude`, `omp`, `copilot`, `cursor`, or any other kind herdr supports. `hq` refuses unknown names before it opens any panes. Changes apply to the next workspace you open; there's nothing to restart.

For `hq team`, if more than one place sets a role's tool, the first of these wins:

1. the environment variable `HQ_KIND_<role>`, for one run (`HQ_KIND_impl=claude hq team …`)
2. `kind_<role>` in the project's `.hq/runtime`
3. `kind_<role>` in this machine's `hq.local`
4. the default

Only Claude has been tried as the manager. Another tool should work if it can run shell commands that last up to 10 minutes.

## Per-project settings for `hq team`

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
