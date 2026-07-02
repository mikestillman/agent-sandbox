#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y \
  build-essential \
  clang \
  lldb \
  cmake \
  ninja-build \
  git \
  curl \
  ca-certificates \
  vim \
  emacs-nox \
  ripgrep \
  fd-find \
  jq \
  python3 \
  python3-pip \
  python3-venv \
  nodejs \
  npm \
  gh \
  ccache \
  pkg-config \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  gosu

rm -rf /var/lib/apt/lists/*
