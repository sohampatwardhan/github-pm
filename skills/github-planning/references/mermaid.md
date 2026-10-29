# Mermaid for plans

Use fenced `mermaid` blocks in the epic and in the status report. Two charts cover planning:

- A `flowchart` dependency DAG, with one subgraph for the epic and one for the child issues
- A `gantt` roadmap

Validate every fence before sharing the document. From the repository root, after Node is available:

```bash
bash scripts/check.sh
```

To check a single file without the rest of the suite:

```bash
npx -y @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.svg
```

`@mermaid-js/mermaid-cli` renders with headless Chrome. If Puppeteer cannot find a browser, pass a config whose `executablePath` is the local Chrome binary and whose `args` include `--no-sandbox`.

## Flowchart

Rules that keep the CLI from rejecting the chart:

- The first line is `flowchart TD`.
- Node ids are camel-case words. Do not use `end`, `subgraph`, or `graph` as an id.
- Put punctuation, including colons, inside quoted labels: `parent["Epic: retry failed checkouts"]`.
- A subgraph has an id and a title: `subgraph children [Child issues]`.
- Close each subgraph with `end`.
- Draw a parent link and a blocked-by link as separate edges. The arrow points from the blocker to the blocked issue, matching "A blocks B".

## Gantt

Rules:

- Include `dateFormat YYYY-MM-DD`.
- A task id sits after the colon and before the start: `Classify retryable failures :classify, 2026-11-02, 5d`.
- Express a dependency with `after classify`, using the task id, not the title.
- Do not put a colon in the task title.

## When the CLI fails

Quote the error, fix the fence, and render again. Do not tell the user the diagram is valid until the command exits 0.
