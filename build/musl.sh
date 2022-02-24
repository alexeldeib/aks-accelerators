#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update && sudo apt-get install -yq make wget git rsync gcc gettext autopoint bison libtool automake pkg-config gperf texinfo patch

echo "setting up work dir"
WORK_DIR="$(pwd)/musl-src"
INSTALL_DIR="${WORK_DIR}/install"
mkdir -p "${WORK_DIR}/install"
pushd "$WORK_DIR"

echo "cloning coreutils sources"
MUSL_VER=1.2.2
git clone git://git.musl-libc.org/musl
pushd musl
git checkout v${MUSL_VER}

echo "setting up build configuration + installing musl"
env CFLAGS="-Os -ffunction-sections -fdata-sections" LDFLAGS='-Wl,--gc-sections' ./configure --prefix="${INSTALL_DIR}"
sudo make install
popd

"${INSTALL_DIR}/bin/musl-gcc" || true

echo "Successfully built and installed muslv v${MUSL_VER}"
