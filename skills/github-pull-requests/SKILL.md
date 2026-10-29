---
name: github-pull-requests
description: "Open and manage GitHub pull requests with gh: PR templates, draft PRs, review requests, CODEOWNERS, and issue-closing keywords. Use when creating a pull request, requesting review, marking a draft ready, or adding a PR template or CODEOWNERS file."
license: MIT
---

# Pull requests

Follow `github-pm` for dry-run and confirmation. Closing keywords and issue links are defined in `github-issues`. This skill covers the pull request side.

## Template

Copy `templates/pull_request_template.md` to one of these paths on the default branch:

- `.github/pull_request_template.md`
- `pull_request_template.md` in the repository root
- `.github/PULL_REQUEST_TEMPLATE/<name>.md` when the repository needs more than one template

`gh pr create --template pull_request_template.md` selects a file in `.github/PULL_REQUEST_TEMPLATE/` or the root. The default template is used when `--template` is omitted and a default file exists.

## Open a pull request

Write the title and body, including a closing keyword when the pull request should close an issue on merge. Keywords work only when the base branch is the repository default. On any other base they are ignored.

```bash
gh pr create --base main --title "Retry checkout charges on 503" --body-file /tmp/pr.md --draft
```

Flags from `gh pr create --help`: `--draft`, `--reviewer` (user or `org/team`, repeatable), `--assignee` (`@me`), `--label`, `--milestone`, `--project` (needs the `project` scope), `--template`, `--body-file`. `--fill` copies the commit subject and body. Prefer an explicit title and body for a planned change.

`gh pr create --dry-run` may still push the branch. Do not use it as a preview. Show the title, base, head, and body instead.

Draft pull requests do not request CODEOWNERS. Request reviewers when opening, or add them later. Convert the draft when the change is ready for those reviews:

```bash
gh pr ready 123
gh pr ready 123 --undo
```

`--undo` turns a ready pull request back into a draft.

## Review requests

```bash
gh pr edit 123 --add-reviewer monalisa --add-reviewer myorg/payments
gh pr edit 123 --remove-reviewer monalisa
```

On github.com, `--add-reviewer "@copilot"` requests a Copilot review. That value is not supported on GitHub Enterprise Server.

A review you submit yourself:

```bash
gh pr review 123 --comment --body "The retry budget should be configurable."
gh pr review 123 --request-changes --body "Idempotency key is not sent on the second attempt."
gh pr review 123 --approve --body "Retry tests cover the 503 path."
```

Use only one of `--comment`, `--request-changes`, and `--approve`.

Check status before merging. Do not merge unless the user asked.

```bash
gh pr view 123 --json reviewDecision,statusCheckRollup,mergeStateStatus,closingIssuesReferences,isDraft
gh pr checks 123
```

`gh pr checks` exits 8 while checks are pending.

## CODEOWNERS

Copy `templates/CODEOWNERS` to `.github/CODEOWNERS`. GitHub also reads a CODEOWNERS file in the repository root or `docs/`, and uses the first of `.github/`, root, then `docs/`.

Rules that matter:

- The last matching pattern wins. Put the broad `*` rule first and specific paths after it.
- Owners on one line share a pattern. A second line with the same pattern replaces the first.
- Owners need write access. A team is `@org/team-name` and needs write access as a team.
- `!` negation, character ranges, and backslash-escaped `#` patterns do not work.
- Paths are case sensitive. The file must be under 3 MB.
- Code owners are not requested on a draft. They are requested when the pull request is marked ready.
- The file that applies is the one on the pull request's base branch.
- Require a code owner review in branch protection or a ruleset only when the user asks. An approval from any owner on the matching line is enough.

## Link the issue

In the pull request body, on the default branch:

```markdown
Fixes #101
```

Cross-repository: `Fixes OWNER/REPO#101`. Several issues each need a keyword: `Fixes #101, fixes #102`. See `github-issues` for the full keyword list.

Read the link back:

```bash
gh pr view 123 --json closingIssuesReferences,url
```

## Edits that wait for confirmation

Closing, reopening, or merging a pull request, and deleting the branch, need a dry-run.

```bash
gh pr close 123 --comment "Superseded by #130."
gh pr merge 123 --squash
```

Do not pass a merge flag unless the user asked to merge.
