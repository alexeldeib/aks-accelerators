#!/usr/bin/env bash
set -euo pipefail

echo "updating path to include go binaries"
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="/root/go"

echo "installing apt skopeo dependencies"
sudo apt update && sudo apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y make file libgpgme-dev libassuan-dev libbtrfs-dev libdevmapper-dev gcc pkg-config

echo "setting up skopeo work dir"
WORKDIR="src-skopeo"
mkdir "$WORKDIR"
pushd "$WORKDIR"

echo "Cloning skopeo"
git clone https://github.com/containers/skopeo

echo "Descending into source dir"
pushd skopeo

echo "building skopeo"
make bin/skopeo

echo "Copying skopeo default-policy.json to config dir"
sudo mkdir -p /etc/containers
sudo cp default-policy.json /etc/containers/policy.json

echo "installing skopeo"
sudo install -m 0555 "bin/skopeo" /usr/local/bin/skopeo 

echo "Copying binary to output folder"
sudo cp -a /usr/local/bin/skopeo "${GITHUB_WORKSPACE}/bin/skopeo"

echo "Successfully built and uploaded skopeo"
