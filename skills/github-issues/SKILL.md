---
name: github-issues
description: "Write and manage GitHub issues with gh: bug, feature, and task bodies, YAML issue forms, triage, deduplication, assignees, sub-issues, organization issue types, closing-keyword links, and milestones. Use when creating or editing issues, issue templates, parent or child issues, blocked-by links, or repository milestones."
license: MIT
---

# GitHub issues

Follow `github-pm` for the dry-run and confirmation rules. Use `github-labels` when the change is the label set itself. Use `github-planning` when the user wants an epic broken into several issues before any of them are filed.

## Search before creating

```bash
gh issue list --state all --limit 20 --search "retry checkout" --json number,title,state,url
```

Search syntax: [searching issues and pull requests](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests). Add `is:issue` inside `--search` when the query should ignore pull requests.

If a match exists, link it and stop. Closing as a duplicate is destructive. Show this command and wait:

```bash
gh issue close 123 --reason duplicate --duplicate-of 456 --comment "Duplicate of #456."
```

`--reason` is `completed`, `not planned`, or `duplicate`.

## Issue bodies

Write a body the maintainer can act on without asking for the basics. Keep the title specific (the failing behavior, the capability, or the outcome), not "bug" or "update".

### Bug

```markdown
## Summary
What broke, in one or two sentences.

## Steps to reproduce
1. ...

## Expected
What should have happened.

## Actual
What happened instead. Include the error text.

## Environment
- Version:
- OS:
- Relevant config:

## Logs
Paste the relevant output in a fenced code block.
```

### Feature

```markdown
## Problem
Who is blocked, and what they cannot do today.

## Proposal
The change you want, including the user-visible behavior.

## Alternatives
What else was considered, and why it lost.

## Acceptance criteria
- [ ] ...
```

### Task

```markdown
## Outcome
What is true when this is done.

## Context
Why this task exists, and the parent issue if it has one.

## Done when
- [ ] ...

## Out of scope
What this task will not change.
```

Show the title and body, then create:

```bash
gh issue create --title "Checkout retries a 503 and charges the card twice" --body-file /tmp/issue.md --label "needs-triage" --type Bug
```

Useful create flags (from `gh issue create --help`): `--label`, `--assignee` (`@me`, `@copilot` on github.com), `--milestone`, `--project` (needs `project` scope), `--type`, `--parent`, `--blocked-by`, `--blocking`, `--template`, `--body-file`. Repeat `--label` or pass a comma-separated list.

## Issue forms

Copy `templates/ISSUE_TEMPLATE/` to the target repository's `.github/ISSUE_TEMPLATE/` on the default branch. Forms are YAML, not Markdown. Required top-level keys: `name`, `description`, `body`. Optional keys: `title`, `labels`, `assignees`, `type`, `projects`.

- `labels` are applied only when that label already exists. Sync labels first (`github-labels`).
- `projects` entries are `OWNER/PROJECT_NUMBER` (the number in the project URL). The person opening the issue needs write access to that project. If reporters do not have it, use the auto-add workflow in `github-repo-hygiene` instead.
- `type` is an organization issue type. User-owned repositories have no issue types. Remove `type:` unless the name exists (see below).
- `blank_issues_enabled: false` in `config.yml` removes the blank issue form. Ship bug, feature, and task forms first, and add a `contact_links` entry for questions. Each contact link needs `name`, `url`, and `about`.
- Body element types: `markdown`, `textarea`, `input`, `dropdown`, `checkboxes`, `upload`. Every non-markdown element needs a unique `id` of letters, numbers, `-`, and `_`.
- `validations.required: true` is enforced on public repositories.
- A YAML comment starts at `#`. Quote Markdown headings inside `markdown` values.

Form schema: [syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms) and [syntax for GitHub's form schema](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-githubs-form-schema).

Check the chooser after the files are on the default branch:

```bash
gh repo view --json isBlankIssuesEnabled,issueTemplates
```

## Triage

1. Confirm it is not a duplicate.
2. Set the kind (issue type, or a `type:*` label).
3. Set one `priority:p0`–`priority:p3` label and one `area:*` label.
4. Remove `needs-triage`.
5. Ask for missing reproduction steps with `needs-info` instead of guessing.
6. Assign an owner and a milestone only when both are known.

```bash
gh issue edit 23 --add-label "priority:p1,area:api" --remove-label "needs-triage" --add-assignee "@me" --type Bug --milestone "v1.4"
```

`--add-assignee` and `--remove-assignee` accept `@me` and, on github.com, `@copilot`. Editing several issue numbers in one command (`gh issue edit 23 34 --add-label "help wanted"`) is a bulk edit: dry-run the numbers first.

`needs-info` loop:

```bash
gh issue comment 23 --body "Please add the version and the response body. I added the needs-info label."
gh issue edit 23 --add-label "needs-info"
```

## Issue types

Issue types belong to an organization (at most 25). Defaults are Task, Bug, and Feature; an org may rename them. They are not available on a user account.

```bash
gh api graphql -f owner='ORG' -f query='
  query($owner: String!) {
    organization(login: $owner) {
      id
      issueTypes(first: 25) {
        nodes { id name description isEnabled color }
      }
    }
  }
'
```

Set a type with `gh issue create --type Bug` or `gh issue edit 23 --type Bug`. Clear it with `gh issue edit 23 --remove-type`. Filter with `gh issue list --type Bug`.

Create a type only when the user asked for a new org-wide type. `color` is `GRAY`, `BLUE`, `GREEN`, `YELLOW`, `ORANGE`, `RED`, `PINK`, or `PURPLE`.

```bash
gh api graphql -f ownerId='ORG_NODE_ID' -f name='Epic' -f description='Parent issue that tracks a body of work' -f query='
  mutation($ownerId: ID!, $name: String!, $description: String) {
    createIssueType(input: {
      ownerId: $ownerId
      name: $name
      description: $description
      isEnabled: true
      color: PURPLE
    }) {
      issueType { id name }
    }
  }
'
```

`deleteIssueType` and disabling a type are destructive. Dry-run the name and wait.

## Sub-issues and dependencies

A parent issue is the epic. Children point at it with `--parent`. The parent can also adopt them.

```bash
gh issue create --title "Classify retryable checkout errors" --body-file child.md --parent 100 --type Task
gh issue edit 100 --add-sub-issue 123,124
gh issue edit 123 --remove-parent
gh issue edit 100 --remove-sub-issue 123
```

Blocked-by is separate from the parent link. Use it for the real dependency, not for every child.

```bash
gh issue create --title "Bounded retry with jitter" --body-file retry.md --parent 100 --blocked-by 101,102
gh issue edit 103 --add-blocked-by 101 --add-blocking 104
gh issue edit 103 --remove-blocked-by 101
```

Read the links back:

```bash
gh issue view 100 --json number,title,parent,subIssues,blockedBy,blocking,issueType,milestone,labels
```

`gh issue develop 123 --name checkout-retry --checkout` creates a linked branch. That writes a git branch. Do it only when the user asked to start the work. `--list` is read-only.

## Milestones

There is no `gh milestone` command. Use the REST API. Full request bodies are in `references/milestones.md`.

```bash
gh api repos/{owner}/{repo}/milestones -f title='v1.4 Checkout retry' -f description='Retry failed checkouts without a double charge.' -f due_on='2026-12-15T00:00:00Z'
gh issue edit 100 --milestone "v1.4 Checkout retry"
```

Closing a milestone (`-X PATCH` with `state=closed`) needs a dry-run of its open issue count and a yes. Prefer closing it from `github-releases` when the release ships.

## Linking issues and pull requests

Closing keywords in a pull request description (or a commit message) link the issue and close it when the pull request merges into the default branch. On any other base branch the keywords do nothing.

Keywords: `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`. A colon or uppercase is fine (`Closes: #10`).

| Target | Example |
| --- | --- |
| Same repository | `Fixes #10` |
| Other repository | `Fixes octo-org/octo-repo#100` |
| Several issues | `Fixes #10, fixes #123, fixes octo-org/octo-repo#100` |

Each issue needs its own keyword. `Fixes #10 and #12` does not close `#12`.

Manual sidebar links are limited to ten issues per pull request. Keyword links are removed by editing the description. See `github-pull-requests` for the create command.

## Commands that wait for confirmation

```bash
gh issue close 123 --reason "not planned" --comment "Out of scope for this repository."
gh issue reopen 123 --comment "Reopening with a reproduction."
gh issue transfer 123 other-owner/other-repo
gh issue delete 123
gh issue lock 123 --reason resolved
gh issue pin 123
```

Lock reasons: `off_topic`, `resolved`, `spam`, `too_heated`. `gh issue delete --yes` skips the prompt. Do not add `--yes` until the user has confirmed that delete.
