#!/usr/bin/env bash
#
# Seed the RAG Voice AI Agent with demo data.
# Creates an equipment record and uploads a sample manual so you have
# something to talk to during the demo.
#
# Usage:
#   ./demo/seed.sh                      # uses defaults (localhost:8000, sample_manual.md)
#   API_BASE=http://localhost:8000 ./demo/seed.sh
#   ./demo/seed.sh /path/to/your/manual.pdf   # upload your own file instead
#
# Requires: the backend running (docker-compose up) and curl + python3.

set -euo pipefail

API_BASE="${API_BASE:-http://localhost:8000}"
TENANT_ID="mvp_tenant"   # MUST match settings.TENANT_ID — the bot filters retrieval on this
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_PATH="${1:-$SCRIPT_DIR/sample_manual.md}"

EQUIP_NAME="Pump X200"
EQUIP_DESC="Industrial single-stage centrifugal water pump"

echo "==> Using API: $API_BASE"
echo "==> Document:  $DOC_PATH"

if [ ! -f "$DOC_PATH" ]; then
  echo "ERROR: document not found: $DOC_PATH" >&2
  exit 1
fi

# 0. Sanity check the backend is up
if ! curl -fsS "$API_BASE/health" >/dev/null 2>&1; then
  echo "ERROR: backend not reachable at $API_BASE/health — is docker-compose up?" >&2
  exit 1
fi
echo "==> Backend is healthy."

# 1. Create equipment (or reuse if it already exists)
echo "==> Creating equipment '$EQUIP_NAME'..."
CREATE_RESP=$(curl -sS -X POST "$API_BASE/api/v1/equipment/" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"$EQUIP_NAME\",\"description\":\"$EQUIP_DESC\",\"tenant_id\":\"$TENANT_ID\"}" \
  -w "\n%{http_code}")

HTTP_CODE=$(printf '%s' "$CREATE_RESP" | tail -n1)
BODY=$(printf '%s' "$CREATE_RESP" | sed '$d')

if [ "$HTTP_CODE" = "201" ]; then
  EQUIPMENT_ID=$(printf '%s' "$BODY" | python3 -c "import sys,json;print(json.load(sys.stdin)['_id'])")
  echo "==> Created equipment: $EQUIPMENT_ID"
elif [ "$HTTP_CODE" = "409" ]; then
  echo "==> Equipment already exists, looking it up..."
  EQUIPMENT_ID=$(curl -sS "$API_BASE/api/v1/equipment/" | \
    python3 -c "import sys,json;d=json.load(sys.stdin);print(next(e['_id'] for e in d if e['name']=='$EQUIP_NAME'))")
  echo "==> Found equipment: $EQUIPMENT_ID"
else
  echo "ERROR: unexpected response ($HTTP_CODE): $BODY" >&2
  exit 1
fi

# 2. Upload + ingest the document (this embeds every chunk — may take a bit)
echo "==> Uploading and embedding document (this can take a moment)..."
UPLOAD_RESP=$(curl -sS -X POST "$API_BASE/api/v1/equipment/$EQUIPMENT_ID/documents" \
  -F "files=@$DOC_PATH" \
  -F "description=Demo manual")

COUNT=$(printf '%s' "$UPLOAD_RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('count',0))")

echo ""
echo "=========================================="
echo " Done."
echo "   Equipment ID : $EQUIPMENT_ID"
echo "   Documents in : $COUNT"
echo ""
echo " Now open the frontend, select '$EQUIP_NAME', click Connect,"
echo " allow the microphone, and start asking questions."
echo "=========================================="
