#!/bin/sh
set -eu
: "${SIGNAL_ACCOUNT:?SIGNAL_ACCOUNT env required}"
CONFIG="${SIGNAL_CONFIG:-/var/lib/signal-cli}"
BIND="${SIGNAL_HTTP_BIND:-127.0.0.1:8080}"

# Setup mode: keep the container alive WITHOUT the daemon, so the account can be
# registered/linked via `kubectl exec` (the running daemon would hold account.db).
if [ "${SIGNAL_SETUP:-0}" = "1" ]; then
  echo "[signal-cli] SIGNAL_SETUP=1 -> daemon NOT started. Register or link via kubectl exec, then unset SIGNAL_SETUP."
  exec sleep infinity
fi

# Fail instead of waiting. A container that loops while unlinked stays "healthy"
# and goes unnoticed; one that exits shows up as CrashLoopBackOff and in the
# restart metrics. The check is local-only (signal-cli stores accounts under an
# internal id keyed by number in accounts.json), so retrying would not change it.
if ! signal-cli --config "$CONFIG" listAccounts 2>/dev/null | grep -qF "$SIGNAL_ACCOUNT"; then
  echo "[signal-cli] ${SIGNAL_ACCOUNT} is not registered/linked -> exit 1." >&2
  echo "[signal-cli] Start with SIGNAL_SETUP=1, then register (primary) or run link.sh (secondary)." >&2
  exit 1
fi

echo "[signal-cli] account found -> starting daemon on ${BIND}"
exec signal-cli --config "$CONFIG" -a "$SIGNAL_ACCOUNT" \
     daemon --http "$BIND" --no-receive-stdout
