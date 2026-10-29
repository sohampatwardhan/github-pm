---
name: github-projects
description: "Create and operate GitHub Projects (v2) with gh project and ProjectV2 GraphQL: custom fields (status, priority, iteration, estimates, dates), board, table, and roadmap views, built-in workflows, adding items, and bulk field updates. Use when the user mentions a project board, project fields, iterations, or gh project."
license: MIT
---

# GitHub Projects (v2)

Follow `github-pm` for dry-run and confirmation. This skill is Projects v2 only. `gh project` does not manage classic project boards.

Projects need the `project` token scope:

```bash
gh auth refresh -s project
```

The project number is the integer in `https://github.com/orgs/ORG/projects/NUMBER` or `https://github.com/users/USER/projects/NUMBER`. `--owner` is the org or user login. Use `--owner "@me"` for the logged-in user.

## Create and inspect

```bash
gh project create --owner "@me" --title "Checkout" --format json
gh project list --owner "@me" --format json
gh project view 1 --owner "@me" --format json
gh project edit 1 --owner "@me" --description "Retry failed checkouts" --readme "See the epic."
gh project link 1 --owner "@me" --repo OWNER/REPO
```

`gh project list --format json` returns `{ "projects": [ ... ], "totalCount": N }`. `gh project view --format json` returns `id` (the node id, `PVT_...`), `number`, `title`, `url`, `public`, `closed`, `shortDescription`, `readme`, `owner.login`, `owner.type`, and item and field counts. Pass `--format json` on create and read `.id` from that object. Do not scrape ids from human-readable output.

User projects cannot be templates. Org projects can:

```bash
gh project mark-template 1 --owner ORG
gh project mark-template 1 --owner ORG --undo
gh project copy 1 --source-owner ORG --target-owner ORG --title "Checkout copy" --drafts
```

`gh project delete` and `gh project close` are destructive. Show the project title and number, then wait. Reopen with `gh project close NUMBER --owner OWNER --undo`.

Visibility is `PUBLIC` or `PRIVATE`:

```bash
gh project edit 1 --owner "@me" --visibility PUBLIC
```

## Fields

List fields before creating one. New projects already have a Status field (single select: Todo, In Progress, Done). Do not create a second Status.

```bash
gh project field-list 1 --owner "@me" --format json --limit 100
```

Each field has `id`, `name`, and `type` (`ProjectV2SingleSelectField`, `ProjectV2IterationField`, or `ProjectV2Field`). Single-select fields include `options[]` of `{id, name}`. This JSON does not include iteration ids or the `dataType` of a plain field. Fetch those with the query in `references/graphql.md`.

`gh project field-create` accepts only `TEXT`, `SINGLE_SELECT`, `DATE`, and `NUMBER`. It cannot create an iteration field or a multi-select field.

```bash
gh project field-create 1 --owner "@me" --name "Priority" --data-type SINGLE_SELECT --single-select-options "P0,P1,P2,P3"
gh project field-create 1 --owner "@me" --name "Estimate" --data-type NUMBER
gh project field-create 1 --owner "@me" --name "Target date" --data-type DATE
gh project field-create 1 --owner "@me" --name "Note" --data-type TEXT
```

`--single-select-options` is a comma-separated list, so an option name cannot contain a comma. Use GraphQL when you need option colors (`GRAY`, `BLUE`, `GREEN`, `YELLOW`, `ORANGE`, `RED`, `PINK`, `PURPLE`) or an iteration field. See `references/graphql.md`.

`gh project field-delete --id FIELD_ID` deletes the field and its values. Dry-run the field name and wait.

Suggested set for a planning board:

| Field | How | Used for |
| --- | --- | --- |
| Status | Built in. Options Todo, In Progress, Done | Board columns |
| Priority | `SINGLE_SELECT` P0–P3 | Ordering |
| Estimate | `NUMBER` | Points or hours |
| Target date | `DATE` | Roadmap bars |
| Sprint | `ITERATION` via GraphQL, usually 7 or 14 days | Sprint planning |

## Items

Add an issue or pull request by its URL. You cannot set a field in the same call; add first, then edit.

```bash
gh project item-add 1 --owner "@me" --url https://github.com/OWNER/REPO/issues/101
gh issue create --title "..." --body "..." --project "Checkout"
```

`--project` on `gh issue create` matches the project title.

Draft items exist only on the project until converted:

```bash
gh project item-create 1 --owner "@me" --title "Decide the retry budget" --body "Cap attempts and delay."
```

List items. `--format json` cannot be combined with `--field`.

```bash
gh project item-list 1 --owner "@me" --format json --limit 100
gh project item-list 1 --owner "@me" --query "assignee:@me is:issue is:open" --limit 50
gh project item-list 1 --owner "@me" --field "Status" --field "Priority"
```

Filter syntax: [filtering projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/filtering-projects). JSON items look like `{ "id", "content": { "type", "title", "number", "url", "repository" }, "status": "Todo" }`. Field names are camel-cased by the CLI (`"Status"` becomes `status`, and only the first character is lowercased). Items the viewer cannot access come back as redacted content.

Set one field on one non-draft item per `item-edit` call.

Single select by option name:

```bash
gh project item-edit 1 --owner "@me" \
  --url https://github.com/OWNER/REPO/issues/101 \
  --field "Status" --value "In Progress"
```

Text, number, date, iteration, or clearing a value use node ids. Get the project id from `gh project view --format json`, the field id from `gh project field-list --format json`, and the item id from `gh project item-list --format json`. Iteration option ids come from GraphQL, not from `field-list`.

```bash
gh project item-edit --id ITEM_ID --project-id PROJECT_ID --field-id FIELD_ID --text "waiting on schema"
gh project item-edit --id ITEM_ID --project-id PROJECT_ID --field-id FIELD_ID --number 3
gh project item-edit --id ITEM_ID --project-id PROJECT_ID --field-id FIELD_ID --date 2026-12-15
gh project item-edit --id ITEM_ID --project-id PROJECT_ID --field-id FIELD_ID --iteration-id ITERATION_ID
gh project item-edit --id ITEM_ID --project-id PROJECT_ID --field-id FIELD_ID --single-select-option-id OPTION_ID
gh project item-edit --id ITEM_ID --project-id PROJECT_ID --field-id FIELD_ID --clear
```

`--date` is `YYYY-MM-DD`. Draft title and body use `--id` plus `--title` and `--body`.

`updateProjectV2ItemFieldValue` cannot change Assignees, Labels, Milestone, or Repository. Those belong to the issue or pull request:

```bash
gh issue edit 101 --add-assignee "@me" --add-label "area:api" --milestone "v1.4 Checkout retry"
```

Archive and delete are destructive. Dry-run the item title and wait.

```bash
gh project item-archive 1 --owner "@me" --id ITEM_ID
gh project item-archive 1 --owner "@me" --id ITEM_ID --undo
gh project item-delete 1 --owner "@me" --id ITEM_ID
```

## Bulk updates

Use `scripts/bulk-set-field.sh`. It prints every item it would change and does nothing else unless `--apply` is present. Show that dry-run and wait for a yes before `--apply`.

```bash
scripts/bulk-set-field.sh --owner "@me" --project 1 --field "Status" --value "Todo" --query "is:open"
scripts/bulk-set-field.sh --owner "@me" --project 1 --field "Estimate" --kind number --number 2 --apply
```

The script refuses to run `--apply` together with a brand-new invocation the user has not seen. Run it once without `--apply`, then again with `--apply` only after confirmation.

## Views

`gh` 2.103.0 cannot create or list views. The GraphQL API can. `ProjectV2ViewLayout` is `BOARD_LAYOUT`, `TABLE_LAYOUT`, or `ROADMAP_LAYOUT`. `createProjectV2View` and `updateProjectV2View` accept `name`, `layout`, `filter`, and `configuration.visibleFieldIds`. They do not accept a group-by field. If the board needs columns grouped by Status, set that in the project UI after the view exists. A roadmap needs a date field such as Target date.

Mutations are in `references/graphql.md`. Deleting a view (`deleteProjectV2View`) waits for confirmation.

There is no items connection on a view. To approximate a view, pass the view's filter string to `gh project item-list --query`.

## Built-in workflows

When a project is created, two workflows are on: closing an issue or pull request sets Status to Done, and merging a pull request sets Status to Done. Other workflows (item added to project, auto-add from a repository, auto-archive, auto-close) are configured in the project UI.

List whatever the API currently returns:

```bash
gh api graphql -f projectId='PROJECT_ID' -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        workflows(first: 20) {
          nodes { id name number enabled }
        }
      }
    }
  }
'
```

The schema introspected on github.com on 2026-10-29 has `deleteProjectV2Workflow` and no mutation that enables or edits a workflow. Do not call `updateProjectV2Workflow`. Turn workflows on, and set their Status value, in the UI: [using the built-in automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations).

To add items from a repository without the UI auto-add workflow, use the Actions template in `github-repo-hygiene`.

Deleting a workflow is permanent. Dry-run the workflow name and wait.

## Status posts

`createProjectV2StatusUpdate` publishes a status on the project. `status` is `ON_TRACK`, `AT_RISK`, `OFF_TRACK`, `COMPLETE`, or `INACTIVE`. Show the body and wait before posting. The planning skill has the report template. The mutation is in `references/graphql.md`.
