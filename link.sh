#!/bin/sh
set -eu
CONFIG="${SIGNAL_CONFIG:-/var/lib/signal-cli}"
NAME="${1:-hermes}"

echo "[signal-cli] linking device '${NAME}' ..."
# 'link' prints the URI as its first line, then blocks until the QR is scanned.
signal-cli --config "$CONFIG" link -n "$NAME" | while IFS= read -r line; do
  case "$line" in
    sgnl://*|tsdevice://*)
      echo; qrencode -t ANSIUTF8 "$line"; echo
      echo "-> On your phone: Signal > Settings > Linked Devices > Link New Device"
      echo "   Scan the QR above. Waiting for the link to complete ..." ;;
    *) printf '%s\n' "$line" ;;
  esac
done
echo "[signal-cli] link complete. Unset SIGNAL_SETUP and restart the container to start the daemon."
