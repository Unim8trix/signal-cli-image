#!/bin/sh
set -eu
: "${SIGNAL_ACCOUNT:?SIGNAL_ACCOUNT env required}"
CONFIG="${SIGNAL_CONFIG:-/var/lib/signal-cli}"
BIND="${SIGNAL_HTTP_BIND:-127.0.0.1:8080}"

# Wait until the device is linked instead of crash-looping.
# TODO verify on first build: signal-cli stores the account under <config>/data/<number>.
while [ ! -e "${CONFIG}/data/${SIGNAL_ACCOUNT}" ]; do
  echo "[signal-cli] ${SIGNAL_ACCOUNT} not linked yet. Link it with:"
  echo "  kubectl exec -it -n hermes deploy/hermes -c signal-cli -- link.sh"
  sleep 10
done

echo "[signal-cli] account linked -> starting daemon on ${BIND}"
exec signal-cli --config "$CONFIG" -a "$SIGNAL_ACCOUNT" \
     daemon --http "$BIND" --no-receive-stdout
