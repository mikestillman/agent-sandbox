#!/usr/bin/env bash
# Container entrypoint. Runs as root: applies the egress firewall, then drops
# privileges to the unprivileged `developer` user for the actual command.
set -euo pipefail

# Default to an interactive shell if no command was given.
if [[ "$#" -eq 0 ]]; then
  set -- bash
fi

if [[ "${SANDBOX_FIREWALL:-1}" == "1" ]]; then
  if ! /usr/local/bin/init-firewall.sh; then
    echo "[entrypoint] FATAL: firewall setup failed; refusing to start." >&2
    echo "[entrypoint] (set SANDBOX_FIREWALL=0 to run without egress restrictions)" >&2
    exit 1
  fi
else
  echo "[entrypoint] WARNING: egress firewall disabled (SANDBOX_FIREWALL=0)." >&2
fi

exec gosu developer "$@"
