# ProjectV2 GraphQL

Call these with `gh api graphql`. String variables use `-f name=value`. The queries below match the public schema checked on github.com on 2026-10-29 (`gh` 2.103.0). Prefer `gh project` when it can do the job. Use GraphQL for iteration fields, option colors, views, workflow listing, and status posts.

Official guide: [using the API to manage Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects).

## Owner and project ids

```bash
gh api graphql -f login='OWNER' -f query='
  query($login: String!) {
    user(login: $login) { id login }
    organization(login: $login) { id login }
  }
'
```

One of `user` or `organization` is null. Or read `id` from `gh project view NUMBER --owner OWNER --format json`.

## Fields, options, and iterations

`gh project field-list` does not return iteration ids. This query does.

```bash
gh api graphql -f projectId='PROJECT_ID' -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        fields(first: 50) {
          nodes {
            ... on ProjectV2Field { id name dataType }
            ... on ProjectV2SingleSelectField {
              id
              name
              options { id name }
            }
            ... on ProjectV2IterationField {
              id
              name
              configuration {
                duration
                startDay
                iterations { id title startDate duration }
                completedIterations { id title startDate }
              }
            }
          }
        }
      }
    }
  }
'
```

Create an iteration field. `duration` is days. Each iteration needs `title`, `startDate` (`YYYY-MM-DD`), and `duration`.

```bash
gh api graphql \
  -f projectId='PROJECT_ID' \
  -f name='Sprint' \
  -f start='2026-11-02' \
  -f query='
  mutation($projectId: ID!, $name: String!, $start: Date!) {
    createProjectV2Field(input: {
      projectId: $projectId
      dataType: ITERATION
      name: $name
      iterationConfiguration: {
        startDate: $start
        duration: 14
        iterations: [
          { title: "Sprint 46", startDate: $start, duration: 14 }
        ]
      }
    }) {
      projectV2Field {
        ... on ProjectV2IterationField { id name }
      }
    }
  }
'
```

`dataType` for `createProjectV2Field` is `TEXT`, `NUMBER`, `DATE`, `SINGLE_SELECT`, `ITERATION`, or `MULTI_SELECT`. Replacing iteration or single-select configuration with `updateProjectV2Field` overwrites the existing configuration. Read it first and send the full desired list back, including existing iteration `id` values you want to keep.

Single select with colors:

```bash
gh api graphql -f projectId='PROJECT_ID' -f query='
  mutation($projectId: ID!) {
    createProjectV2Field(input: {
      projectId: $projectId
      dataType: SINGLE_SELECT
      name: "Priority"
      singleSelectOptions: [
        { name: "P0", color: RED, description: "Drop everything" }
        { name: "P1", color: ORANGE, description: "This sprint" }
        { name: "P2", color: YELLOW, description: "Do soon" }
        { name: "P3", color: BLUE, description: "Nice to have" }
      ]
    }) {
      projectV2Field {
        ... on ProjectV2SingleSelectField { id name }
      }
    }
  }
'
```

## Set a field value

Add the item first (`addProjectV2ItemById` or `gh project item-add`). Then update. Only one of `text`, `number`, `date`, `singleSelectOptionId`, `iterationId`, or `multiSelectOptionIds` may be set.

```bash
gh api graphql \
  -f projectId='PROJECT_ID' -f itemId='ITEM_ID' -f fieldId='FIELD_ID' -f iterationId='ITERATION_ID' \
  -f query='
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $iterationId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId
      itemId: $itemId
      fieldId: $fieldId
      value: { iterationId: $iterationId }
    }) {
      projectV2Item { id }
    }
  }
'
```

Clear a value with `clearProjectV2ItemFieldValue` (`projectId`, `itemId`, `fieldId`). This does not work for Assignees, Labels, Milestone, or Repository.

A bulk update is one mutation per item. Use `scripts/bulk-set-field.sh` for the CLI path, and the same dry-run rule for a GraphQL loop: print every item id and value, then wait.

## Views

```bash
gh api graphql -f projectId='PROJECT_ID' -f query='
  mutation($projectId: ID!) {
    createProjectV2View(input: {
      projectId: $projectId
      name: "Board"
      layout: BOARD_LAYOUT
    }) {
      projectV2View { id name layout }
    }
  }
'
```

`layout` is `BOARD_LAYOUT`, `TABLE_LAYOUT`, or `ROADMAP_LAYOUT`. To change the filter or the visible columns:

```bash
gh api graphql -f viewId='VIEW_ID' -f query='
  mutation($viewId: ID!) {
    updateProjectV2View(input: {
      viewId: $viewId
      name: "Roadmap"
      layout: ROADMAP_LAYOUT
      filter: "is:open"
    }) {
      projectV2View { id name filter }
    }
  }
'
```

`visibleFieldIds` goes under `configuration`. Group-by is not an input on this mutation. Set column grouping in the UI. `deleteProjectV2View` takes `viewId` and needs confirmation.

## Workflows and status

Listing workflows is in the skill. The only workflow mutation in this schema is `deleteProjectV2Workflow` (`workflowId`). There is no enable or edit mutation.

Post a status update only after the user accepts the text:

```bash
gh api graphql -f projectId='PROJECT_ID' -f body='Checkout retry is on track. Classify and idempotency are in progress.' -f query='
  mutation($projectId: ID!, $body: String!) {
    createProjectV2StatusUpdate(input: {
      projectId: $projectId
      body: $body
      status: ON_TRACK
      startDate: "2026-11-02"
      targetDate: "2026-12-15"
    }) {
      statusUpdate { id }
    }
  }
'
```

`status` is `ON_TRACK`, `AT_RISK`, `OFF_TRACK`, `COMPLETE`, or `INACTIVE`.
