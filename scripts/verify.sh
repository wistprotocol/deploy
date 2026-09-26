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
CURL=(curl -fsS --max-time 15)
if [ -n "${VERIFY_CA:-}" ]; then
  CURL+=(--cacert "$VERIFY_CA")
elif [[ "$HOST" =~ ^[0-9.]+$ || "$HOST" == \[* ]]; then
  ssh -o StrictHostKeyChecking=accept-new "root@${HOST#[}" cat /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt > "$RUN/ca-$HOST.crt"
  CURL+=(--cacert "$RUN/ca-$HOST.crt")
fi
"${CURL[@]}" -o "$RUN/anchor.json" "$BASE/log/anchor.json"
"${CURL[@]}" -o "$RUN/checkpoint" "$BASE/checkpoint"
python3 "$HERE/scripts/verify-checkpoint.py" "$RUN/anchor.json" "$RUN/checkpoint" "$@"
