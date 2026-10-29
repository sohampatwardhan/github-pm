#!/usr/bin/env bash
# Parse templates, check skill frontmatter, dry-run the scripts, render Mermaid.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
errors = []

try:
    import yaml
except ImportError:
    print("PyYAML is required", file=sys.stderr)
    sys.exit(1)

name_re = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
skills = sorted(p for p in (root / "skills").iterdir() if p.is_dir())
if len(skills) < 2:
    errors.append("expected several skills under skills/")

for skill in skills:
    md = skill / "SKILL.md"
    if not md.is_file():
        errors.append(f"missing {md}")
        continue
    text = md.read_text()
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        errors.append(f"{md} is missing YAML frontmatter")
        continue
    data = yaml.safe_load(match.group(1))
    if not isinstance(data, dict):
        errors.append(f"{md} frontmatter is not a mapping")
        continue
    name = data.get("name")
    description = data.get("description")
    if name != skill.name:
        errors.append(f"{md} name {name!r} does not match folder {skill.name!r}")
    if not isinstance(name, str) or not name_re.match(name) or len(name) > 64:
        errors.append(f"{md} has an invalid name")
    if not isinstance(description, str) or not description.strip():
        errors.append(f"{md} is missing a description")
    elif len(description) > 1024:
        errors.append(f"{md} description is {len(description)} characters")

for path in sorted(root.rglob("*")):
    if path.suffix.lower() not in {".yml", ".yaml", ".json"}:
        continue
    if any(part in {".git", "node_modules"} for part in path.parts):
        continue
    raw = path.read_text()
    try:
        if path.suffix.lower() == ".json":
            json.loads(raw)
        else:
            loaded = yaml.safe_load(raw)
            if loaded is None:
                errors.append(f"{path} parsed as empty")
    except Exception as exc:  # noqa: BLE001 - report the file and stop later
        errors.append(f"{path} failed to parse: {exc}")

yml = yaml.safe_load((root / "skills/github-labels/templates/labels.yml").read_text())
js = json.loads((root / "skills/github-labels/templates/labels.json").read_text())
if yml != js:
    errors.append("labels.yml and labels.json differ")

fence = re.compile(r"^```mermaid[ \t]*\n(.*?)^```[ \t]*$", re.M | re.S)
diagrams = []
for path in sorted(root.rglob("*.md")):
    if any(part in {".git", "node_modules"} for part in path.parts):
        continue
    text = path.read_text()
    found = fence.findall(text)
    opens = len(re.findall(r"^```mermaid[ \t]*$", text, re.M))
    if opens != len(found):
        errors.append(f"{path} has {opens} mermaid fences and {len(found)} closed blocks")
    for index, body in enumerate(found, start=1):
        diagrams.append((path, index, body))

out = Path("/tmp/github-pm-mermaid")
if out.exists():
    for child in out.iterdir():
        child.unlink()
else:
    out.mkdir(parents=True)
manifest = []
for index, (path, nth, body) in enumerate(diagrams):
    dest = out / f"{index:02d}.mmd"
    dest.write_text(body if body.endswith("\n") else body + "\n")
    manifest.append(f"{dest.name}\t{path.relative_to(root)}#{nth}")
(out / "manifest.tsv").write_text("\n".join(manifest) + ("\n" if manifest else ""))
print(f"templates ok, {len(diagrams)} mermaid fences")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
PY

bash -n skills/github-labels/scripts/sync-labels.sh
bash -n skills/github-projects/scripts/bulk-set-field.sh

stub="$(mktemp -d)"
trap 'rm -rf "$stub"' EXIT
cat >"$stub/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
joined="$*"
if [[ "$joined" == *"label list"* ]]; then
  printf '%s\n' '[{"name":"needs-triage","color":"ffffff","description":"old"}]'
  exit 0
fi
if [[ "$joined" == *"label create"* || "$joined" == *"label delete"* ]]; then
  echo "refusing to mutate in the checker: $joined" >&2
  exit 3
fi
if [[ "$joined" == *"item-list"* ]]; then
  printf '%s\n' '{"items":[{"id":"PVTI_1","content":{"type":"Issue","title":"Classify","number":101,"url":"https://github.com/OWNER/REPO/issues/101","repository":"OWNER/REPO"}}],"totalCount":1}'
  exit 0
fi
if [[ "$joined" == *"project view"* ]]; then
  printf '%s\n' '{"id":"PVT_1","number":7,"title":"Checkout","owner":{"login":"OWNER","type":"Organization"}}'
  exit 0
fi
if [[ "$joined" == *"field-list"* ]]; then
  printf '%s\n' '{"fields":[{"id":"PVTSSF_1","name":"Status","type":"ProjectV2SingleSelectField","options":[{"id":"opt_todo","name":"Todo"},{"id":"opt_done","name":"Done"}]}],"totalCount":1}'
  exit 0
fi
if [[ "$joined" == *"item-edit"* ]]; then
  echo "refusing to mutate in the checker: $joined" >&2
  exit 3
fi
echo "unexpected gh invocation: $joined" >&2
exit 4
EOF
chmod +x "$stub/gh"

PATH="$stub:$PATH" skills/github-labels/scripts/sync-labels.sh \
  --file skills/github-labels/templates/labels.yml --repo OWNER/REPO >/tmp/github-pm-label-dry.txt
grep -q "Dry run only" /tmp/github-pm-label-dry.txt
grep -q "create" /tmp/github-pm-label-dry.txt

set +e
PATH="$stub:$PATH" skills/github-labels/scripts/sync-labels.sh \
  --file skills/github-labels/templates/labels.yml --repo OWNER/REPO --apply >/tmp/github-pm-label-apply.txt
status=$?
set -e
if [[ "$status" -ne 3 ]]; then
  echo "expected sync-labels --apply to call gh label create, status $status" >&2
  exit 1
fi

PATH="$stub:$PATH" skills/github-projects/scripts/bulk-set-field.sh \
  --owner OWNER --project 7 --field Status --value Todo >/tmp/github-pm-bulk-dry.txt
grep -q "Dry run only" /tmp/github-pm-bulk-dry.txt
grep -q "item-edit" /tmp/github-pm-bulk-dry.txt

set +e
PATH="$stub:$PATH" skills/github-projects/scripts/bulk-set-field.sh \
  --owner OWNER --project 7 --field Status --value Todo --apply >/tmp/github-pm-bulk-apply.txt
status=$?
set -e
if [[ "$status" -ne 3 ]]; then
  echo "expected bulk-set-field --apply to call gh project item-edit, status $status" >&2
  exit 1
fi

chrome="${PUPPETEER_EXECUTABLE_PATH:-}"
if [[ -z "$chrome" ]]; then
  for candidate in /usr/local/bin/google-chrome /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser; do
    if [[ -x "$candidate" ]]; then
      chrome="$candidate"
      break
    fi
  done
fi
if [[ -z "$chrome" ]]; then
  echo "Chrome is required to render Mermaid. Set PUPPETEER_EXECUTABLE_PATH." >&2
  exit 1
fi

puppeteer="$(mktemp)"
python3 -c 'import json,sys; json.dump({"executablePath": sys.argv[1], "args": ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"]}, sys.stdout)' "$chrome" >"$puppeteer"

if command -v mmdc >/dev/null 2>&1; then
  renderer=(mmdc)
else
  renderer=(npx --yes @mermaid-js/mermaid-cli)
fi

while IFS="$(printf '\t')" read -r file source; do
  [[ -z "$file" ]] && continue
  echo "render $source"
  "${renderer[@]}" -i "/tmp/github-pm-mermaid/$file" -o "/tmp/github-pm-mermaid/${file%.mmd}.svg" -p "$puppeteer" -b white
done < /tmp/github-pm-mermaid/manifest.tsv

echo "check passed"
