# Status report: PROJECT NAME

- Date: YYYY-MM-DD
- Project status: ON_TRACK
- Milestone: MILESTONE (due YYYY-MM-DD)
- Iteration: SPRINT NAME

## Summary

One short paragraph a reader who missed the week can use.

## Finished

- #101 Title

## In progress

- #102 Title. Owner. What is left.

## Next

- #103 Title. It is blocked by #102.

## Risks

- Risk, the consequence, and the next step.

## Roadmap

```mermaid
gantt
    title Project roadmap
    dateFormat YYYY-MM-DD
    axisFormat %b %d
    section Now
    Finished work      :done, finished, 2026-11-02, 4d
    Current work       :active, current, after finished, 5d
    section Next
    Following work     :following, after current, 4d
```

## Dependency view

```mermaid
flowchart TD
  subgraph epic [Epic]
    parent["Parent issue"]
  end
  subgraph children [Child issues]
    first["First task"]
    second["Second task"]
  end
  parent --> first
  parent --> second
  first --> second
```
