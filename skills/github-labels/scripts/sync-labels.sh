#!/usr/bin/env bash
# Sync GitHub labels from a YAML or JSON file.
# Default is a dry run. --apply creates and updates. --prune deletes labels
# that are not in the file and is refused unless --apply is also set.
set -euo pipefail

FILE=""
REPO=""
APPLY=0
PRUNE=0

usage() {
  cat <<'EOF'
Usage: sync-labels.sh [--file labels.yml|labels.json] [--repo OWNER/REPO] [--apply] [--prune]

The file must be an object with a "labels" array. Each entry needs "name" and
"color" (6 hex digits, leading # optional). "description" is optional.

With no --apply flag, the script prints the plan and changes nothing.
--prune lists labels present in the repo but not in the file. Combining
--prune with --apply deletes them.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="${2-}"; shift 2 ;;
    --repo) REPO="${2-}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --prune) PRUNE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$FILE" ]]; then
  if [[ -f labels.yml ]]; then
    FILE="labels.yml"
  elif [[ -f labels.yaml ]]; then
    FILE="labels.yaml"
  elif [[ -f labels.json ]]; then
    FILE="labels.json"
  else
    echo "Pass --file, or run from a directory that contains labels.yml or labels.json." >&2
    exit 2
  fi
fi

if [[ ! -f "$FILE" ]]; then
  echo "File not found: $FILE" >&2
  exit 2
fi

if [[ "$PRUNE" -eq 1 && "$APPLY" -eq 1 ]]; then
  echo "Prune will delete repository labels that are not in $FILE." >&2
fi

remote="$(mktemp)"
trap 'rm -f "$remote"' EXIT

list_args=(label list --limit 1000 --json name,color,description)
if [[ -n "$REPO" ]]; then
  list_args+=(--repo "$REPO")
fi
gh "${list_args[@]}" >"$remote"

plan="$(
  python3 - "$FILE" "$remote" <<'PY'
import json, sys
from pathlib import Path

file_path, remote_path = sys.argv[1:]
raw = Path(file_path).read_text()
if file_path.endswith(".json"):
    data = json.loads(raw)
else:
    import yaml
    data = yaml.safe_load(raw)

if not isinstance(data, dict) or not isinstance(data.get("labels"), list):
    sys.stderr.write('File must be an object with a "labels" array.\n')
    sys.exit(1)

wanted = []
seen = set()
for item in data["labels"]:
    if not isinstance(item, dict) or "name" not in item or "color" not in item:
        sys.stderr.write(f"Each label needs name and color: {item!r}\n")
        sys.exit(1)
    name = str(item["name"]).strip()
    color = str(item["color"]).strip().lstrip("#").lower()
    description = "" if item.get("description") is None else str(item["description"])
    if not name:
        sys.stderr.write("Label name is empty.\n")
        sys.exit(1)
    if name in seen:
        sys.stderr.write(f"Duplicate label name: {name}\n")
        sys.exit(1)
    seen.add(name)
    if len(color) != 6 or any(c not in "0123456789abcdef" for c in color):
        sys.stderr.write(f"Color for {name} must be 6 hex digits, got {item['color']!r}\n")
        sys.exit(1)
    if "\n" in description or "\t" in description:
        sys.stderr.write(f"Description for {name} must be a single line.\n")
        sys.exit(1)
    wanted.append({"name": name, "color": color, "description": description})

remote = json.loads(Path(remote_path).read_text() or "[]")
by_name = {}
for row in remote:
    by_name[row["name"]] = {
        "color": str(row.get("color") or "").lstrip("#").lower(),
        "description": row.get("description") or "",
    }

plan = {"create": [], "update": [], "unchanged": [], "prune": []}
for label in wanted:
    current = by_name.get(label["name"])
    if current is None:
        plan["create"].append(label)
    elif current["color"] != label["color"] or current["description"] != label["description"]:
        plan["update"].append({"label": label, "from": current})
    else:
        plan["unchanged"].append(label["name"])

wanted_names = {label["name"] for label in wanted}
for name in sorted(by_name):
    if name not in wanted_names:
        plan["prune"].append(name)

print(json.dumps(plan))
PY
)"

PLAN_JSON="$plan" python3 <<'PY'
import json, os
plan = json.loads(os.environ["PLAN_JSON"])

def line(kind, text):
    print(f"{kind:10} {text}")

for label in plan["create"]:
    line("create", f"{label['name']}  {label['color']}  {label['description']}")
for row in plan["update"]:
    label = row["label"]
    old = row["from"]
    line("update", f"{label['name']}  color {old['color']} -> {label['color']}")
    if old["description"] != label["description"]:
        line(
            "update",
            f"{label['name']}  description {old['description']!r} -> {label['description']!r}",
        )
for name in plan["unchanged"]:
    line("unchanged", name)
for name in plan["prune"]:
    line("prune", name)
print()
print(
    f"create {len(plan['create'])}, update {len(plan['update'])}, "
    f"unchanged {len(plan['unchanged'])}, prune {len(plan['prune'])}"
)
PY

if [[ "$APPLY" -ne 1 ]]; then
  echo
  echo "Dry run only. Re-run with --apply to create and update."
  if [[ "$PRUNE" -eq 1 ]]; then
    echo "Prune was requested. Re-run with --apply --prune only after the prune list is confirmed."
  fi
  exit 0
fi

repo_args=()
if [[ -n "$REPO" ]]; then
  repo_args=(--repo "$REPO")
fi

PLAN_JSON="$plan" python3 <<'PY' | while IFS="$(printf '\t')" read -r name color description; do
import json, os
plan = json.loads(os.environ["PLAN_JSON"])
for label in plan["create"] + [row["label"] for row in plan["update"]]:
    print("\t".join([label["name"], label["color"], label["description"]]))
PY
  gh label create "$name" --color "$color" --description "$description" --force "${repo_args[@]}"
done

if [[ "$PRUNE" -ne 1 ]]; then
  echo "Apply finished. Labels not in the file were left in place."
  exit 0
fi

python3 -c '
import json, sys
plan = json.loads(sys.argv[1])
for name in plan["prune"]:
    print(name)
' "$plan" | while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  gh label delete "$name" --yes "${repo_args[@]}"
done
