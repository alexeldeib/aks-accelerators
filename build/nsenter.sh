#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update && sudo apt-get install -yq curl make wget git rsync gcc gettext autopoint bison libtool automake pkg-config gperf texinfo patch

echo "setting up work dir"
WORKDIR="$(pwd)/nsenter-src"
mkdir -p "$WORKDIR"
pushd "$WORKDIR"

UTIL_LINUX_VER=2.37
curl -L -O https://github.com/karelzak/util-linux/archive/v${UTIL_LINUX_VER}.tar.gz
tar -xf v${UTIL_LINUX_VER}.tar.gz && mv util-linux-${UTIL_LINUX_VER} util-linux

# make static version
cd util-linux
./autogen.sh && ./configure
make -j$(nproc) LDFLAGS="--static" nsenter

die()
{
    B=$(basename "$0")
    echo "$B: error: $@" >&2
    exit 1
}

check_static_binary()
{
    F="$1"
    test -z "$F" && die "missing file name param (in check_static_binary)"

    test -e "$F" || die "build failed: can't find '$F'"
    file -i "$F" | grep -Eq 'application/x-executable' \
        || die "build failed: '$F' is not a binary executable"
    ldd $F || true
    ldd $F > static.out 2>&1 || exit_code=$?
    cat static.out | grep -q 'not a dynamic executable' || die "build failed: '$F' is not a static binary executable"
}

# export CC="$(pwd)/musl-src/install/bin/musl-gcc"

# "$CC" || true
check_static_binary nsenter

echo "Copying binary to output folder"
cp -a nsenter "${GITHUB_WORKSPACE}/bin/nsenter"

echo "Successfully built and uploaded binary"
