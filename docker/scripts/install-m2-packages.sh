#!/usr/bin/env bash
# Install the system dependencies needed to build Macaulay2 from source, for
# BOTH the autotools and CMake build paths.
#
# The library list is the official build-from-source list from the M2 wiki
# (https://github.com/Macaulay2/M2/wiki/Building-M2-from-source-using-Autotools),
# which uses ONLY the standard Ubuntu archive -- no PPA. The macaulay2 PPA ships
# the prebuilt binary, not build dependencies, so it is intentionally not used
# here. Anything not found as a system package is built automatically by CMake;
# the packages below just speed that up. Newer dependency versions come from a
# newer base image, not from a PPA.
#
# Build-tool coverage:
#   autotools: autoconf, automake, libtool-bin, bison, flex, make, texinfo
#   cmake:     cmake (>=3.24; Ubuntu 24.04 ships 3.28), ninja-build, ccache
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update

# Meta-build tooling for both build systems (not part of the M2 library list).
apt-get install -y --no-install-recommends \
  ca-certificates \
  ccache \
  cmake \
  curl \
  ninja-build \
  texinfo

# Macaulay2 build-from-source library dependencies (verbatim from the M2 wiki, deduped).
apt-get install -y --no-install-recommends \
  4ti2 \
  autoconf \
  automake \
  bison \
  cohomcalg \
  coinor-csdp \
  fflas-ffpack \
  flex \
  g++ \
  gfan \
  gfortran \
  git \
  install-info \
  libboost-dev \
  libboost-regex-dev \
  libboost-stacktrace-dev \
  libcdd-dev \
  libeigen3-dev \
  libffi-dev \
  libflint-dev \
  libfplll-dev \
  libfrobby-dev \
  libgc-dev \
  libgdbm-dev \
  libgivaro-dev \
  libglpk-dev \
  libgmp-dev \
  libgtest-dev \
  libjansson-dev \
  liblzma-dev \
  libmathic-dev \
  libmathicgb-dev \
  libmemtailor-dev \
  libmpfi-dev \
  libmpfr-dev \
  libmps-dev \
  libnauty-dev \
  libncurses-dev \
  libnormaliz-dev \
  libntl-dev \
  libopenblas-dev \
  libpython3-dev \
  libreadline-dev \
  libsingular-dev \
  libtbb-dev \
  libtool-bin \
  libxml2-dev \
  lrslib \
  make \
  msolve \
  nauty \
  normaliz \
  patch \
  pkgconf \
  python3 \
  singular-data \
  time \
  topcom \
  wget \
  zlib1g-dev

apt-get clean
rm -rf /var/lib/apt/lists/*
