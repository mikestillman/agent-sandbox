#!/usr/bin/env bash
# Install the latest stable *prebuilt* Macaulay2 from the official PPA, alongside
# the from-source build produced elsewhere. This gives a known-good reference
# binary (currently M2 1.26.06) and, importantly, ships the Emacs integration.
#
# Runs at IMAGE BUILD TIME only. The egress firewall is applied by the entrypoint
# at container *start*, not during `docker build`, so the launchpad PPA is
# reachable here without touching the runtime allowlist. To update the packaged
# M2 later, rebuild the image (the sandbox intentionally has no runtime apt).
#
# The prebuilt lands in /usr/bin; a from-source `make install` goes to
# /usr/local/bin (earlier on PATH), so the two coexist and `M-x M2` launches
# whichever M2 is first on PATH.
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
# software-properties-common provides add-apt-repository (+ launchpadlib for ppa:).
apt-get install -y --no-install-recommends software-properties-common
add-apt-repository -y ppa:macaulay2/macaulay2
apt-get update
# elpa-macaulay2 (the Emacs mode) is only a *recommend* of macaulay2, so it must
# be named explicitly here since we use --no-install-recommends.
apt-get install -y --no-install-recommends macaulay2 elpa-macaulay2

# --- Emacs integration -------------------------------------------------------
# elpa-macaulay2 installs the Emacs mode as a Debian ELPA package, which emacs's
# 00debian.el auto-activates for all sessions -- so `M-x M2` already works via
# the autoloads. We additionally load M2-init.el to get M2's standard key
# bindings (f11/f12 etc.), the full in-Emacs experience. This goes in the
# system-wide site-start.d rather than ~/.emacs because /home/developer is a
# bind mount at runtime and would shadow anything baked into the image home.
# Discover the path (it carries the M2 version) and prefer the activated elpa/
# copy over the elpa-src/ source copy.
M2_INIT="$(dpkg -L elpa-macaulay2 | grep -E '/elpa/.*/M2-init\.el$' | head -1 || true)"
if [[ -z "$M2_INIT" ]]; then
  M2_INIT="$(dpkg -L elpa-macaulay2 | grep -E '/M2-init\.el$' | head -1 || true)"
fi

if [[ -n "$M2_INIT" ]]; then
  install -d /etc/emacs/site-start.d
  cat > /etc/emacs/site-start.d/50macaulay2.el <<EOF
;; Load Macaulay2's Emacs mode for all users (run M-x M2 to start a session).
;; Generated at image build time by install-m2-prebuilt.sh.
(let* ((m2-init "$M2_INIT")
       (m2-dir (file-name-directory m2-init)))
  (when (file-exists-p m2-init)
    (add-to-list 'load-path m2-dir)
    (load m2-init)))
EOF
  echo "[install-m2-prebuilt] wired Emacs M2 mode -> $M2_INIT"
else
  echo "[install-m2-prebuilt] WARNING: M2-init.el not found; Emacs M2 integration not configured" >&2
fi

apt-get clean
rm -rf /var/lib/apt/lists/*
