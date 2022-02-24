#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update && sudo apt-get install -yq make wget git rsync gcc gettext autopoint bison libtool automake pkg-config gperf texinfo patch perl

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

export CC="${GITHUB_WORKSPACE}/musl-src/install/bin/musl-gcc"
"$CC" || true

echo "setting up work dir"
WORKDIR="$(pwd)/sleep-src"
mkdir -p "$WORKDIR"
pushd "$WORKDIR"

echo "cloning coreutils sources"
COREUTILS_VER=9.0
git clone https://github.com/coreutils/coreutils.git
cd coreutils
git checkout v${COREUTILS_VER}

./bootstrap

FORCE_UNSAFE_CONFIGURE=1 ./configure --disable-gcc-warnings || (cat config.log; exit)

# sudo cp /usr/lib/gcc/x86_64-linux-gnu/9/crtbeginT.o /usr/lib/gcc/x86_64-linux-gnu/9/crtbeginT.orig.o
# sudo cp /usr/lib/gcc/x86_64-linux-gnu/9/crtbeginS.o /usr/lib/gcc/x86_64-linux-gnu/9/crtbeginT.o

echo "listing targets for sleep"
# make -f local.mk -qp | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1,A,/ /);for(i in A)print A[i]}' | sort -u 

echo "attempting to build"
make -j$(nproc) CFLAGS='-static -static-libgcc -static-libstdc++ -fPIC'
stat src/sleep
set -x
ldd src/sleep || true
check_static_binary src/sleep
echo "Copying binary to output folder"
cp -a src/sleep "${GITHUB_WORKSPACE}/bin/sleep"

echo "Successfully built and uploaded binary"
