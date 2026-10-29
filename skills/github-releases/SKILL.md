---
name: github-releases
description: "Cut a GitHub release with gh release, categorize generated notes with .github/release.yml, maintain a changelog, and close the matching milestone. Use when tagging a version, drafting release notes, or closing a release milestone."
license: MIT
---

# Releases

Follow `github-pm` for dry-run and confirmation. Publishing a release and closing a milestone are public. Draft first.

## Categories

Copy `templates/release.yml` to `.github/release.yml` on the default branch. Generated notes group merged pull requests by label. The `*` category is the catch-all and must be last. `ignore-for-release` is in the label taxonomy from `github-labels`.

| Key | Role |
| --- | --- |
| `changelog.exclude.labels` | Drop pull requests with any of these labels from the notes |
| `changelog.exclude.authors` | Drop pull requests by these logins |
| `changelog.categories[].title` | Section heading |
| `changelog.categories[].labels` | Labels that place a pull request in the section. `*` matches whatever is left |
| `changelog.categories[].exclude.labels` | Labels excluded from that one section |
| `changelog.categories[].exclude.authors` | Authors excluded from that one section |

Reference: [automatically generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes).

## Draft the release

Pick a tag the repository does not already use. Look first:

```bash
gh release list --limit 20 --json tagName,name,isDraft,isPrerelease,publishedAt
```

Create a draft. `--generate-notes` calls the release notes API and writes a title unless `--title` is set. `--notes` is prepended to generated notes. `--notes-start-tag` sets the previous tag. If the tag does not exist, `gh release create` creates it from the default branch unless `--target` or `--verify-tag` is set.

```bash
gh release create v1.4.0 --draft --target main --title "v1.4.0" --generate-notes --notes-start-tag v1.3.0
```

`--verify-tag` aborts when the tag is not already on the remote. Use that when the tag was cut locally and pushed on purpose. `--fail-on-no-commits` aborts when nothing landed since the previous release. It does not apply to the first release. `--latest=false` keeps this release from becoming Latest. A prerelease is `--prerelease`.

Show the draft body:

```bash
gh release view v1.4.0 --json tagName,name,isDraft,body,url
```

Edit the notes if categories are missing labels, then publish only after the user accepts the text:

```bash
gh release edit v1.4.0 --notes-file /tmp/notes.md --draft=false
```

`--discussion-category` opens a discussion when the draft is published. The category name must already exist. See `github-repo-hygiene`.

Immutable releases freeze the tag and assets once published. Attach assets before publishing. `gh release create` with files uploads them on a draft and then publishes, unless `--draft` is set.

```bash
gh release create v1.4.0 --draft ./dist/app.tar.gz
```

Deleting a release needs confirmation. `--cleanup-tag` also deletes the git tag. `--yes` skips the prompt. Do not add it until the user has confirmed that tag.

```bash
gh release delete v1.4.0 --cleanup-tag
```

## Changelog

Keep `CHANGELOG.md` at the repository root when the project already has one, or start it from `templates/CHANGELOG.md`. Put the same sections the release notes use. The GitHub release is the announcement. The changelog is the file readers see in the clone. Update it in the release pull request, not after the tag exists, so the tag contains the entry.

Do not paste generated notes that include someone else's commit messages verbatim into a changelog if the user only asked for the GitHub release. The release already has them.

## Close the milestone

After the release is published, list what is still open on the milestone. Close the milestone only when that list is empty or the user accepts leaving those issues open.

```bash
gh issue list --milestone "v1.4 Checkout retry" --state open --json number,title,url
gh api -X PATCH repos/{owner}/{repo}/milestones/MILESTONE_NUMBER -f state=closed
```

Find `MILESTONE_NUMBER` with the list command in `github-issues` `references/milestones.md`. Closing is a dry-run plus confirmation.
