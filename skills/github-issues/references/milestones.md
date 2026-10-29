# Milestones

`gh` 2.103.0 has no milestone subcommand. Use `gh api` against the REST endpoints. `{owner}` and `{repo}` are filled from the current repository. `due_on` is ISO 8601 (`YYYY-MM-DDTHH:MM:SSZ`).

List:

```bash
gh api --paginate repos/{owner}/{repo}/milestones -X GET -f state=open -f sort=due_on -f direction=asc --jq '.[] | {number, title, due_on, open_issues, closed_issues, state}'
```

Create:

```bash
gh api repos/{owner}/{repo}/milestones \
  -f title='v1.4 Checkout retry' \
  -f description='Retry failed checkouts without a double charge.' \
  -f state=open \
  -f due_on='2026-12-15T00:00:00Z'
```

Update the title, description, due date, or state:

```bash
gh api -X PATCH repos/{owner}/{repo}/milestones/1 \
  -f title='v1.4 Checkout retry' \
  -f due_on='2026-12-18T00:00:00Z'
```

Closing is a state change. List open issues on it first (`gh issue list --milestone "v1.4 Checkout retry" --state open`), show the PATCH, and wait for confirmation:

```bash
gh api -X PATCH repos/{owner}/{repo}/milestones/1 -f state=closed
```

Reopen with `-f state=open`. Delete is destructive:

```bash
gh api -X DELETE repos/{owner}/{repo}/milestones/1
```

Attach an issue or pull request by milestone title:

```bash
gh issue edit 100 --milestone "v1.4 Checkout retry"
gh issue edit 100 --remove-milestone
gh pr create --milestone "v1.4 Checkout retry" --title "..." --body "..."
```

Reference: [REST API endpoints for milestones](https://docs.github.com/en/rest/issues/milestones).
