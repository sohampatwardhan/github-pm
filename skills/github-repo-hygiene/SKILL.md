---
name: github-repo-hygiene
description: "Set up GitHub repository hygiene: CONTRIBUTING, SECURITY, Discussions, stale-issue handling, and Actions that add items to a Project or label pull requests by path. Use when configuring community health files or project automation workflows."
license: MIT
---

# Repository hygiene

Follow `github-pm` for dry-run and confirmation. `gh repo edit` changes repository settings. Show the flag and wait before running it.

See what is already on:

```bash
gh repo view --json nameWithOwner,hasDiscussionsEnabled,hasIssuesEnabled,hasProjectsEnabled,isSecurityPolicyEnabled,isBlankIssuesEnabled,defaultBranchRef
```

## CONTRIBUTING and SECURITY

Copy `templates/CONTRIBUTING.md` to `CONTRIBUTING.md` or `.github/CONTRIBUTING.md`. Copy `templates/SECURITY.md` to `SECURITY.md`, `.github/SECURITY.md`, or `docs/SECURITY.md`. GitHub looks in that order for the security policy.

Replace OWNER, REPO, and the supported-version rows before committing. Do not invent a security email. If the user has none, point at the repository's private vulnerability reporting (`https://github.com/OWNER/REPO/security/advisories/new`) and say that private reporting must be enabled in the repository settings.

Check:

```bash
gh repo view --json isSecurityPolicyEnabled,securityPolicyUrl
```

## Discussions

Enable discussions only after confirmation:

```bash
gh repo edit OWNER/REPO --enable-discussions
```

Categories are created in the repository settings. List them, then open a discussion when the user asked for one:

```bash
gh api graphql -f owner='OWNER' -f name='REPO' -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      id
      discussionCategories(first: 20) {
        nodes { id name }
      }
    }
  }
'
```

```bash
gh api graphql \
  -f repositoryId='REPO_NODE_ID' -f categoryId='CATEGORY_ID' \
  -f title='How should checkout retries behave?' \
  -f body='Looking for a decision on the retry budget.' \
  -f query='
  mutation($repositoryId: ID!, $categoryId: ID!, $title: String!, $body: String!) {
    createDiscussion(input: {
      repositoryId: $repositoryId
      categoryId: $categoryId
      title: $title
      body: $body
    }) {
      discussion { url }
    }
  }
'
```

Show the title and body before `createDiscussion`. Point the issue-form contact link (`github-issues`) at the discussions URL so questions do not land in the tracker.

## Stale issues

Copy `templates/workflows/stale.yml` to `.github/workflows/stale.yml`. The template pins `actions/stale@v11` and sets `debug-only: true`, so a run logs what it would mark and closes nothing. Read a debug log before changing `debug-only` to `false`. That change lets the workflow close issues, which needs an explicit yes.

The template waits 60 days before the `stale` label and 14 days more before closing. It exempts `priority:p0`, `good first issue`, and every milestone. The close reason is `not_planned`. The label name `stale` matches `github-labels`. Create that label before the workflow runs for real (`github-labels`).

Inputs checked against `actions/stale` v11.0.0 (`action.yml`). Useful ones: `days-before-issue-stale`, `days-before-issue-close`, `exempt-issue-labels`, `exempt-all-milestones`, `close-issue-reason`, `debug-only`.

## Add issues and pull requests to a project

The GraphQL schema checked on 2026-10-29 cannot turn on the built-in "auto-add to project" workflow. Copy `templates/workflows/add-to-project.yml` to `.github/workflows/add-to-project.yml` when items should join a project as they are opened.

The workflow uses `actions/add-to-project@v2`. `project-url` looks like `https://github.com/orgs/ORG/projects/1` or `https://github.com/users/USER/projects/1`. `github-token` is a secret named `ADD_TO_PROJECT_PAT`, not `GITHUB_TOKEN`. Classic tokens need the `project` scope, and `repo` as well for a private repository. Fine-grained tokens need organization Projects read and write, plus Issues and Pull requests read. Do not print the token.

`labeled` is a comma-separated list. `label-operator` is `OR` (default), `AND`, or `NOT`. Supported events include `issues` `opened`, `reopened`, `transferred`, and `labeled`, and `pull_request` `opened`, `reopened`, and `labeled`.

Replace the project URL before committing. Status for a newly added item is set by the project's "item added" workflow in the UI, not by this action.

## Label by path

Copy `templates/labeler.yml` to `.github/labeler.yml` and `templates/workflows/labeler.yml` to `.github/workflows/labeler.yml`. The workflow pins `actions/labeler@v7` (v7.0.0, 2026-07-21). v7 keeps the v5 configuration shape and the same inputs. The action README's sample workflow still shows `@v6`. Use `@v7`.

The workflow uses `pull_request_target` so it can label PRs from forks. Do not add a step that checks out or runs the pull request's code in that workflow.

```yaml
area:docs:
  - changed-files:
      - any-glob-to-any-file: "**/*.md"
```

`any-glob-to-any-file` means any glob matches any changed file. `sync-labels: true` removes a configured label when the files no longer match. It never removes a label that is absent from `labeler.yml`. Leave it false unless the user wants removal.

The labels must already exist or the action cannot apply them. Sync with `github-labels` first.

## Issue forms and the blank issue

Disabling blank issues is `blank_issues_enabled: false` in `.github/ISSUE_TEMPLATE/config.yml`, from `github-issues`. Do that only after bug, feature, and task forms exist, and after a contact link points somewhere real.
