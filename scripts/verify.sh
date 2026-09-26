#!/bin/bash
# usage: scripts/verify.sh BASE_URL [PUBLIC_KEY...]
# Fetch the Anchor and head Checkpoint from BASE_URL and verify the Checkpoint
# under the Anchor's genesis key (plus any extra public keys). A base URL whose
# host is an IP address is served by the server's own CA: the root certificate
# is fetched over SSH as root and kept in run/, unless VERIFY_CA names it already.
set -euo pipefail
BASE=${1:?usage: verify.sh BASE_URL [PUBLIC_KEY...]}; shift
HERE=$(cd "$(dirname "$0")/.." && pwd)
HOST=${BASE#https://}; HOST=${HOST%%/*}
RUN="$HERE/run"; mkdir -p "$RUN"
CA=()
if [ -n "${VERIFY_CA:-}" ]; then
  CA=(--cacert "$VERIFY_CA")
elif [[ "$HOST" =~ ^[0-9.]+$ || "$HOST" == \[* ]]; then
  ssh -o StrictHostKeyChecking=accept-new "root@${HOST#[}" cat /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt > "$RUN/ca-$HOST.crt"
  CA=(--cacert "$RUN/ca-$HOST.crt")
fi
CURL=(curl -fsS --max-time 15 "${CA[@]}")
"${CURL[@]}" -o "$RUN/anchor.json" "$BASE/log/anchor.json"
if ! "${CURL[@]}" -o "$RUN/checkpoint" "$BASE/checkpoint" 2>/dev/null; then
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "${CA[@]}" "$BASE/checkpoint")
  if [ "$code" = 404 ]; then
    echo "$BASE serves Log $(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["anchor"]["log_id"])' "$RUN/anchor.json") but no Checkpoint yet: the first Epoch seals at the next cadence instant; rerun after it" >&2
  else
    echo "$BASE/checkpoint: HTTP $code" >&2
  fi
  exit 1
fi
python3 "$HERE/scripts/verify-checkpoint.py" "$RUN/anchor.json" "$RUN/checkpoint" "$@"
