#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y \
  autoconf \
  automake \
  libtool \
  bison \
  flex \
  texinfo \
  libgmp-dev \
  libmpfr-dev \
  libflint-dev \
  libntl-dev \
  libboost-all-dev \
  libeigen3-dev \
  libreadline-dev \
  libgc-dev \
  libffi-dev \
  libxml2-dev \
  libxml2-utils

rm -rf /var/lib/apt/lists/*
