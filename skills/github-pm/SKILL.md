---
name: github-pm
description: "Route GitHub project-management work and require a dry-run plus confirmation before closing, deleting, or bulk-editing. Use when the task touches GitHub issues, Projects (v2), planning, labels, pull requests, releases, or repository hygiene and the specialist skill is not already chosen."
license: MIT
---

# GitHub project management

This is the router. Read it, pick one specialist skill, and follow that skill. Do not improvise GitHub commands from memory when a skill already gives the command.

| Task | Skill |
| --- | --- |
| Issue bodies, issue forms, triage, duplicates, assignees, sub-issues, issue types, milestones, closing keywords | `github-issues` |
| Projects (v2): fields, views, workflows, items, bulk field edits, `gh project`, ProjectV2 GraphQL | `github-projects` |
| Split an epic or spec into dependent issues, iteration or roadmap planning, status reports, Mermaid diagrams | `github-planning` |
| Label taxonomy, or syncing labels from YAML or JSON | `github-labels` |
| Pull request template, draft PR, review requests, CODEOWNERS, linking a PR to issues | `github-pull-requests` |
| Release notes, `.github/release.yml`, tags, changelog, closing a release milestone | `github-releases` |
| CONTRIBUTING, SECURITY, Discussions, stale issues, Actions that add items to a project or label by path | `github-repo-hygiene` |

Planning work usually continues in `github-issues` and `github-projects` after the plan is accepted. Say which skill you are following.

## Safety

These actions need a dry-run and an explicit yes before they run:

- Closing, reopening, deleting, transferring, or locking an issue or pull request
- Deleting or pruning labels, fields, project items, views, workflows, or projects
- Bulk edits (more than one issue, label, or project item)
- Publishing a release, deleting a release, or deleting a tag (`--cleanup-tag`)
- Closing a milestone
- Changing repository settings (`gh repo edit`)
- Posting a project status update

A dry-run lists every object and the exact command that would change it. Creating one issue, one label, or one draft pull request that the user already asked for does not need a second confirmation, but show the title and body before creating it.

Never pass `--yes` (or `-y`) until the user has confirmed that specific command. `gh pr create --dry-run` is not a safe preview: it may still push commits.

## Context to load first

```bash
gh --version
gh auth status
gh repo view --json nameWithOwner,isInOrganization,defaultBranchRef,hasIssuesEnabled,hasProjectsEnabled,hasDiscussionsEnabled,isSecurityPolicyEnabled
```

Projects need the `project` scope. If `gh project` or `gh issue create --project` returns an authorization error:

```bash
gh auth refresh -s project
```

Commands below were checked against `gh` 2.103.0 (2026-10-21). If `gh --version` is newer or older, run `gh <command> --help` before using a flag this skill does not show. Do not invent flags, GraphQL fields, or action inputs.

## Install

Skills in this repository live in `skills/<name>/`. See the repository README for Claude Code, Cursor, Kiro, and `.agents/skills/` paths.
