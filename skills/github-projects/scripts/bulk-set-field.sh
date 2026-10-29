#!/usr/bin/env bash
# Set one Projects v2 field on many items.
# Prints the planned edits and exits unless --apply is passed.
# Run once without --apply, show the output, and pass --apply only after confirmation.
set -euo pipefail

OWNER=""
PROJECT=""
FIELD=""
QUERY=""
LIMIT="100"
KIND="single-select"
VALUE=""
NUMBER=""
DATE=""
TEXT=""
ITERATION_ID=""
APPLY=0

usage() {
  cat <<'EOF'
Usage: bulk-set-field.sh --owner OWNER --project NUMBER --field NAME [options]

Options:
  --query STRING     Projects filter, for example: is:open -status:Done
  --limit N          Max items to fetch (default 100)
  --kind KIND        single-select (default), text, number, date, iteration, clear
  --value STRING     Option name for --kind single-select
  --text STRING      Value for --kind text
  --number N         Value for --kind number
  --date YYYY-MM-DD  Value for --kind date
  --iteration-id ID  Iteration id for --kind iteration
  --apply            Perform the edits. Without this flag, nothing is changed.

The script edits one field per item. Draft items have no URL and are skipped
for --kind single-select. Other kinds use the item id.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="${2-}"; shift 2 ;;
    --project) PROJECT="${2-}"; shift 2 ;;
    --field) FIELD="${2-}"; shift 2 ;;
    --query) QUERY="${2-}"; shift 2 ;;
    --limit) LIMIT="${2-}"; shift 2 ;;
    --kind) KIND="${2-}"; shift 2 ;;
    --value) VALUE="${2-}"; shift 2 ;;
    --text) TEXT="${2-}"; shift 2 ;;
    --number) NUMBER="${2-}"; shift 2 ;;
    --date) DATE="${2-}"; shift 2 ;;
    --iteration-id) ITERATION_ID="${2-}"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$OWNER" || -z "$PROJECT" || -z "$FIELD" ]]; then
  echo "Required: --owner, --project, and --field." >&2
  usage >&2
  exit 2
fi

case "$KIND" in
  single-select)
    if [[ -z "$VALUE" ]]; then
      echo "--kind single-select requires --value." >&2
      exit 2
    fi
    ;;
  text)
    if [[ -z "$TEXT" ]]; then
      echo "--kind text requires --text." >&2
      exit 2
    fi
    ;;
  number)
    if [[ -z "$NUMBER" ]]; then
      echo "--kind number requires --number." >&2
      exit 2
    fi
    ;;
  date)
    if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      echo "--kind date requires --date YYYY-MM-DD." >&2
      exit 2
    fi
    ;;
  iteration)
    if [[ -z "$ITERATION_ID" ]]; then
      echo "--kind iteration requires --iteration-id." >&2
      exit 2
    fi
    ;;
  clear) ;;
  *)
    echo "Unknown --kind: $KIND" >&2
    exit 2
    ;;
esac

list_args=(project item-list "$PROJECT" --owner "$OWNER" --format json --limit "$LIMIT")
if [[ -n "$QUERY" ]]; then
  list_args+=(--query "$QUERY")
fi

items_json="$(gh "${list_args[@]}")"
project_json="$(gh project view "$PROJECT" --owner "$OWNER" --format json)"
fields_json="$(gh project field-list "$PROJECT" --owner "$OWNER" --format json --limit 100)"

plan="$(
  ITEMS_JSON="$items_json" PROJECT_JSON="$project_json" FIELDS_JSON="$fields_json" \
    FIELD="$FIELD" KIND="$KIND" VALUE="$VALUE" TEXT="$TEXT" NUMBER="$NUMBER" \
    DATE="$DATE" ITERATION_ID="$ITERATION_ID" PROJECT="$PROJECT" OWNER="$OWNER" \
    python3 - <<'PY'
import json, os, shlex, sys

items = json.loads(os.environ["ITEMS_JSON"])
project = json.loads(os.environ["PROJECT_JSON"])
fields = json.loads(os.environ["FIELDS_JSON"])
field_name = os.environ["FIELD"]
kind = os.environ["KIND"]
project_number = os.environ["PROJECT"]
owner = os.environ["OWNER"]

matches = [f for f in fields.get("fields", []) if f.get("name") == field_name]
if len(matches) != 1:
    names = ", ".join(sorted(f.get("name", "") for f in fields.get("fields", [])))
    sys.stderr.write(
        f"Field {field_name!r} matched {len(matches)} fields. Known names: {names}\n"
    )
    sys.exit(1)
field = matches[0]
project_id = project["id"]
field_id = field["id"]

def argv(*parts):
    return " ".join(shlex.quote(str(p)) for p in parts)

planned = []
skipped = []
for item in items.get("items", []):
    content = item.get("content") or {}
    title = content.get("title") or item.get("id")
    url = content.get("url") or ""
    item_id = item.get("id") or ""
    if kind == "single-select":
        if not url:
            skipped.append(title)
            continue
        cmd = argv(
            "gh", "project", "item-edit", project_number,
            "--owner", owner, "--url", url,
            "--field", field_name, "--value", os.environ["VALUE"],
        )
    else:
        if not item_id:
            skipped.append(title)
            continue
        base = [
            "gh", "project", "item-edit",
            "--id", item_id, "--project-id", project_id, "--field-id", field_id,
        ]
        if kind == "text":
            base += ["--text", os.environ["TEXT"]]
        elif kind == "number":
            base += ["--number", os.environ["NUMBER"]]
        elif kind == "date":
            base += ["--date", os.environ["DATE"]]
        elif kind == "iteration":
            base += ["--iteration-id", os.environ["ITERATION_ID"]]
        elif kind == "clear":
            base += ["--clear"]
        cmd = argv(*base)
    planned.append({"title": title, "command": cmd})

print(json.dumps({
    "field": field_name,
    "fieldId": field_id,
    "projectId": project_id,
    "kind": kind,
    "planned": planned,
    "skipped": skipped,
}))
PY
)"

PLAN_JSON="$plan" python3 <<'PY'
import json, os
plan = json.loads(os.environ["PLAN_JSON"])
print(f"Field: {plan['field']} ({plan['fieldId']})")
print(f"Project: {plan['projectId']}")
print(f"Kind: {plan['kind']}")
print(f"Planned edits: {len(plan['planned'])}")
for row in plan["planned"]:
    print(f"- {row['title']}")
    print(f"  {row['command']}")
if plan["skipped"]:
    print("Skipped (no URL or item id):")
    for title in plan["skipped"]:
        print(f"- {title}")
PY

if [[ "$APPLY" -ne 1 ]]; then
  echo
  echo "Dry run only. Re-run with --apply after the list above is confirmed."
  exit 0
fi

echo
echo "Applying."
PLAN_JSON="$plan" python3 <<'PY' | while IFS= read -r cmd; do
import json, os
plan = json.loads(os.environ["PLAN_JSON"])
for row in plan["planned"]:
    print(row["command"])
PY
  # shellcheck disable=SC2086
  bash -c "$cmd"
done
