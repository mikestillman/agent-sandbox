#!/usr/bin/env bash
# Egress allowlist for the agent sandbox.
#
# Default-deny outbound traffic; only the domains needed by Claude Code, Codex,
# and normal git/npm dev work are permitted. Adapted from Anthropic's
# .devcontainer/init-firewall.sh.
#
# Runs as root at container start (see entrypoint.sh). Requires NET_ADMIN.
# Fails closed: if the allowlist cannot be enforced, the script exits non-zero
# and the container refuses to start.
set -euo pipefail
IFS=$'\n\t'

log() { echo "[firewall] $*"; }

# --- Domains resolved via DNS and pinned into the ipset -----------------------
# github.com / api.github.com are covered by the GitHub meta ranges below, but
# the *.githubusercontent.com asset CDNs and codeload are not, so list them here.
ALLOWED_DOMAINS=(
  # Anthropic / Claude Code (required)
  api.anthropic.com
  claude.ai
  platform.claude.com
  # OpenAI / Codex (required; both auth modes)
  auth.openai.com
  chatgpt.com
  api.openai.com
  # Package registry + GitHub release/asset CDNs (install, update, dev work)
  registry.npmjs.org
  codeload.github.com
  raw.githubusercontent.com
  objects.githubusercontent.com
  release-assets.githubusercontent.com
)

# Extra domains from the environment (comma- or space-separated), e.g.
# ALLOWLIST_EXTRA="pypi.org files.pythonhosted.org"
if [[ -n "${ALLOWLIST_EXTRA:-}" ]]; then
  IFS=', ' read -r -a _extra <<<"${ALLOWLIST_EXTRA}"
  ALLOWED_DOMAINS+=("${_extra[@]}")
  IFS=$'\n\t'
fi

# --- Preserve Docker's embedded DNS (127.0.0.11) NAT rules before flushing ----
DOCKER_DNS_RULES=$(iptables-save -t nat | grep '127\.0\.0\.11' || true)

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

if [[ -n "$DOCKER_DNS_RULES" ]]; then
  log "restoring Docker DNS NAT rules"
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# --- Baseline allow rules (before we lock down) -------------------------------
# DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT  -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
# Loopback
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
# Optional: outbound SSH (git over ssh). Off by default — it's an open exfil
# channel to any host. Enable with ALLOW_SSH=1 if you use ssh git remotes.
if [[ "${ALLOW_SSH:-0}" == "1" ]]; then
  log "allowing outbound SSH (ALLOW_SSH=1)"
  iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
  iptables -A INPUT  -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
fi

ipset create allowed-domains hash:net

# --- GitHub IP ranges from the meta API --------------------------------------
log "fetching GitHub IP ranges"
gh_ranges=$(curl -s --connect-timeout 10 https://api.github.com/meta || true)
if [[ -z "$gh_ranges" ]] || ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null 2>&1; then
  log "ERROR: could not fetch/parse GitHub IP ranges"
  exit 1
fi
while read -r cidr; do
  [[ "$cidr" =~ ^[0-9.]+/[0-9]{1,2}$ ]] || continue
  ipset add allowed-domains "$cidr" 2>/dev/null || true
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | grep -E '^[0-9]+\.')

# --- Resolve and add the allowlisted domains ---------------------------------
for domain in "${ALLOWED_DOMAINS[@]}"; do
  [[ -z "$domain" ]] && continue
  ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
  if [[ -z "$ips" ]]; then
    log "ERROR: failed to resolve $domain"
    exit 1
  fi
  while read -r ip; do
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || continue
    ipset add allowed-domains "$ip" 2>/dev/null || true
  done <<<"$ips"
  log "added $domain"
done

# --- Allow the local Docker/host network (opt-out) ---------------------------
# Lets the container reach the host and sibling services. Disable with
# ALLOW_HOST_NETWORK=0 for a tighter box (may affect some docker networking).
if [[ "${ALLOW_HOST_NETWORK:-1}" == "1" ]]; then
  HOST_IP=$(ip route | awk '/default/ {print $3; exit}')
  if [[ -n "$HOST_IP" ]]; then
    HOST_NETWORK=$(echo "$HOST_IP" | sed 's/\.[0-9]*$/.0\/24/')
    log "allowing host network $HOST_NETWORK"
    iptables -A INPUT  -s "$HOST_NETWORK" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
  fi
fi

# --- IPv6: deny by default (fail closed) -------------------------------------
# The allowlist above is IPv4-only. If the container has any IPv6 connectivity,
# leaving ip6tables at its default ACCEPT policy would be an exfil path straight
# around the allowlist, so drop all IPv6 except loopback. Guarded because not
# every host exposes a usable ip6tables to the container.
if command -v ip6tables >/dev/null 2>&1 && ip6tables -L >/dev/null 2>&1; then
  ip6tables -F
  ip6tables -X
  ip6tables -P INPUT DROP
  ip6tables -P FORWARD DROP
  ip6tables -P OUTPUT DROP
  ip6tables -A INPUT  -i lo -j ACCEPT
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
  log "IPv6 locked down (default DROP)"
else
  log "ip6tables unavailable; skipping IPv6 lockdown (IPv6 likely disabled)"
fi

# --- Lock down ---------------------------------------------------------------
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
# Fast, explicit rejection so blocked calls fail immediately instead of hanging.
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# --- Verify (fail closed) ----------------------------------------------------
log "verifying..."
if curl --connect-timeout 5 -sS https://example.com >/dev/null 2>&1; then
  log "ERROR: reached example.com — allowlist is NOT enforced"
  exit 1
fi
if ! curl --connect-timeout 5 -sS https://api.github.com/zen >/dev/null 2>&1; then
  log "ERROR: cannot reach api.github.com — allowlist too strict / DNS broken"
  exit 1
fi
log "egress allowlist active."
