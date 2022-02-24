#!/usr/bin/env bash
set -euo pipefail

echo "updating path to include go binaries"
export PATH="$PATH:/usr/local/go/bin"
export GOPATH="/root/go"

echo "installing umoci dependencies"
sudo apt update && sudo apt install -y apt-transport-https git

echo "setting up work dir"
WORKDIR="$(mktemp -d)"
pushd "$WORKDIR"

echo "Cloning umoci"
git clone https://github.com/opencontainers/umoci

echo "Descending to source folder"
pushd "umoci/cmd/umoci"

echo "Building umoci"
CGO_ENABLED=0 go build -o umoci .

echo "installing umoci"
sudo install -m 0555 umoci /usr/local/bin/umoci 

echo "Copying binary to output folder"
sudo cp -a /usr/local/bin/umoci  "${GITHUB_WORKSPACE}/bin/umoci"

echo "Successfully built and uploaded"
