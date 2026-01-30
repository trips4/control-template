PE_CONSOLE="lab1-prim01.triplo.psedemos.com"
TOKEN="0M4BYrMT_ZSptn3LzYsP6A6B1C9XXZYvKA6UDKAWD5qM"
PARENT_ID="f2e6aa9b-f537-4ddd-b8c6-c85bf5e910ab"
# 1) Get all groups and compute the subtree (all descendants of PARENT_ID)
SUBTREE_JSON=$(
  curl -ks "https://${PE_CONSOLE}:4433/classifier-api/v1/groups" \
    -H "X-Authentication: ${TOKEN}" \
  | jq --arg pid "$PARENT_ID" '
      . as $all
      | def descendants(parent_id):
          ($all | map(select(.parent == parent_id))) as $children
          | if ($children | length) == 0 then
              []
            else
              $children
              + ($children
                  | map(.id)
                  | map(descendants(.))
                  | add)
            end;
        descendants($pid)
    '
)
# 2) Loop over each group in the subtree and fetch matching nodes
echo "$SUBTREE_JSON" | jq -c '.[] | {id, name}' | while read -r group; do
  GID=$(echo "$group"  | jq -r '.id')
  GNAME=$(echo "$group"| jq -r '.name')
  echo
  echo "=== Group: ${GNAME} (${GID}) ==="
  curl -ks "https://${PE_CONSOLE}:4433/classifier-api/v1/groups/${GID}/nodes" \
    -H "X-Authentication: ${TOKEN}" \
  | jq -r '.[]?' | sed 's/^/  - /'
done