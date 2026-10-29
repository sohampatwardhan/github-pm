---
name: github-labels
description: "Apply a prefixed GitHub label taxonomy and sync repository labels from a YAML or JSON file with a dry-run-first script. Use when creating, renaming, auditing, or bulk-updating labels, or when an issue form needs its labels to exist."
license: MIT
---

# Labels

Follow `github-pm` for dry-run and confirmation. Issue types (`github-issues`) are the kind axis when the repository owner is an organization. Labels carry priority, area, and workflow. Do not also encode Status as labels. Status belongs on the project.

## Taxonomy

One label from each group at a time, except area when a change really crosses two areas.

| Prefix | Values | Meaning |
| --- | --- | --- |
| `type:` | `bug`, `feature`, `task`, `epic` | Kind. Drop `type:bug`, `type:feature`, and `type:task` from the file when the org issue types Bug, Feature, and Task are in use. Keep `type:epic` unless the org has an Epic type. |
| `priority:` | `p0`, `p1`, `p2`, `p3` | P0 is drop-everything. P3 is nice to have. |
| `area:` | `api`, `ui`, `docs`, `ci`, `security` | Where the change lives. Add an area rather than overloading `type:`. |
| workflow | `needs-triage`, `needs-info`, `blocked`, `good first issue`, `help wanted` | Queue state that is not the project Status field. |
| release | `breaking-change`, `dependencies`, `ignore-for-release` | Release notes. `ignore-for-release` matches the exclude list in `github-releases`. |
| automation | `stale` | Applied by the stale workflow in `github-repo-hygiene`. |

Colors are six hex digits with no `#`. The canonical file is `templates/labels.yml`. `templates/labels.json` is the same list.

Estimates are a project number field, not a label. Add `size:` labels only when the repository has no project.

## Inspect

`gh label list` returns 30 labels unless you raise the limit.

```bash
gh label list --limit 1000 --json name,color,description
gh label list --search "priority" --json name,color,description
```

JSON fields: `color`, `createdAt`, `description`, `id`, `isDefault`, `name`, `updatedAt`, `url`.

## Sync

`scripts/sync-labels.sh` compares the file with the repository. With no extra flags it prints create, update, and unchanged lines and changes nothing. `--apply` creates and updates. `--prune` lists labels that are not in the file. Prune deletes those labels, so it requires `--apply` and a prior dry-run the user has accepted. Deleting a label removes it from open issues.

```bash
scripts/sync-labels.sh --file templates/labels.yml --repo OWNER/REPO
scripts/sync-labels.sh --file templates/labels.yml --repo OWNER/REPO --apply
scripts/sync-labels.sh --file templates/labels.yml --repo OWNER/REPO --prune
scripts/sync-labels.sh --file templates/labels.yml --repo OWNER/REPO --prune --apply
```

The file shape is:

```yaml
labels:
  - name: "priority:p1"
    color: "d93f0b"
    description: "Do this sprint"
```

`name` and `color` are required. `color` is six hex digits. `description` is a single line.

The script shells out to:

```bash
gh label create "priority:p1" --color d93f0b --description "Do this sprint" --force
gh label delete "old-name" --yes
```

`--force` updates the color and description when the name already exists. It does not rename. A rename is `gh label edit OLD --name NEW`, which is a separate change: show the old and new names and wait, because issues keep the label under the new name.

Copying labels from another repository, without deleting extras:

```bash
gh label clone source-owner/source-repo --repo dest-owner/dest-repo
gh label clone source-owner/source-repo --repo dest-owner/dest-repo --force
```

`--force` overwrites same-named labels in the destination. It does not delete destination-only labels.

## One label

```bash
gh label create "area:billing" --description "Charges, invoices, and refunds" --color 1d76db
gh label edit "area:billing" --color 0e4f9e --description "Billing, invoices, and refunds"
```

`gh label delete` prompts. The script's prune path passes `--yes` only after `--apply`. Do not pass `--yes` yourself until the user has confirmed that name.
