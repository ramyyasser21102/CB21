# Issue tracker: Linear

Issues for this repo live in Linear, team **RY21** (key `RY21`), reached through the `claude.ai Linear` MCP tools. This repo has no git remote, so there are no PRs to track.

## Conventions

- **Create an issue**: `save_issue` with team `RY21`. Put the title and markdown body in the call.
- **Read an issue**: `get_issue` by identifier (e.g. `RY21-12`). Use `list_comments` for the discussion.
- **List and search issues**: `list_issues` with team, state, label or query filters.
- **Comment**: `save_comment` on the issue.
- **Apply or remove labels**: `save_issue` with the label names. Create missing labels with `save_issue_label`.
- **Close**: `save_issue` and set the state to Done or Canceled. Use `list_issue_statuses` to get the state names.

## When a skill says "publish to the issue tracker"

Create a Linear issue in team RY21.

## When a skill says "fetch the relevant ticket"

Call `get_issue` with the identifier, and `list_comments` for the thread.
