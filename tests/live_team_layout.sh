#!/usr/bin/env bash
# Real herdr: build a team on a repo, check panes and agents, then close it.
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
repo=${1:?repo}; label=hqlive
bin/hq team "$repo" "noop: reply to the human that this is a layout test and do nothing else" "$label"
ws=$(herdr workspace list | jq -r --arg l "$label" '.result.workspaces[] | select(.label==$l) | .workspace_id')
assert_eq "$(herdr workspace get "$ws" | jq -r '.result.workspace.pane_count // .result.pane_count')" 7 "seven panes"
agents=$(herdr agent list | jq -r --arg w "$ws" '.result.agents[] | select(.workspace_id==$w) | "\(.name)=\(.agent)"' | sort | paste -sd' ')
assert_eq "$agents" "$label-impl=cursor $label-manager=claude $label-planner=omp $label-specrev=copilot $label-taskrev=claude" "five agents"
herdr workspace close "$ws" >/dev/null
herdr workspace focus "$HERDR_WORKSPACE_ID" >/dev/null
finish
