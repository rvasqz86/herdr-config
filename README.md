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

5. Restart herdr (or run `herdr server reload-config`) so it picks up the keybindings, then press `ctrl+alt+n` for the `hq new` picker.

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
