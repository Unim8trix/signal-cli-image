#!/bin/sh
set -eu
: "${SIGNAL_ACCOUNT:?SIGNAL_ACCOUNT env required}"
CONFIG="${SIGNAL_CONFIG:-/var/lib/signal-cli}"
BIND="${SIGNAL_HTTP_BIND:-127.0.0.1:8080}"

# Wait until the account is linked instead of crash-looping. signal-cli stores
# accounts under an internal id (data/<id>) keyed by number in accounts.json, so
# ask signal-cli via listAccounts rather than checking a number-named file path.
while ! signal-cli --config "$CONFIG" listAccounts 2>/dev/null | grep -qF "$SIGNAL_ACCOUNT"; do
  echo "[signal-cli] ${SIGNAL_ACCOUNT} not linked yet. Link it with:"
  echo "  kubectl exec -it -n hermes deploy/hermes -c signal-cli -- link.sh"
  sleep 10
done

echo "[signal-cli] account linked -> starting daemon on ${BIND}"
exec signal-cli --config "$CONFIG" -a "$SIGNAL_ACCOUNT" \
     daemon --http "$BIND" --no-receive-stdout
