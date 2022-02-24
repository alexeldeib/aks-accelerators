#!/usr/bin/env bash
set -euo pipefail

echo "setting up work dir"
WORKDIR="$(mktemp -d)"
pushd "$WORKDIR"

function logexec() {
    echo "$@"
    $@
}

# define component versions
gpu_driver_version="470.57.02"
nvidia_container_runtime_version="3.6.0-1"
nvidia_toolkit_version="1.6.0-1"

# set up nvidia apt repos
release=$(lsb_release -r -s)
curl -fsSL https://nvidia.github.io/nvidia-docker/gpgkey > /tmp/aptnvidia.gpg
sudo apt-key add /tmp/aptnvidia.gpg
curl -fsSL https://nvidia.github.io/nvidia-docker/ubuntu${release}/nvidia-docker.list > /tmp/nvidia-docker.list
sudo mv /tmp/nvidia-docker.list /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update

# download all components
NVIDIA_PACKAGES="libnvidia-container1 libnvidia-container-tools nvidia-container-toolkit"
for package in $NVIDIA_PACKAGES; do
    sudo apt-get install --download-only $package=$nvidia_toolkit_version
done
sudo apt-get install --download-only nvidia-container-runtime=$nvidia_container_runtime_version
download_url="https://us.download.nvidia.com/tesla/$gpu_driver_version/NVIDIA-Linux-x86_64-$gpu_driver_version.run"
wget $download_url > wget.log 2>&1
tail -n 30 wget.log

# pull a docker base image
logexec ~/.cache/bin/skopeo copy docker://docker.io/library/ubuntu:20.04 oci:ubuntu-oci:2004

# insert nvidia components to base image
logexec ~/.cache/bin/umoci insert --image ubuntu-oci:2004 ~/.cache/bin/sleep /opt/bin/sleep
logexec ~/.cache/bin/umoci insert --image ubuntu-oci:2004 ~/.cache/bin/nsenter /opt/bin/nsenter
logexec ~/.cache/bin/umoci insert --image ubuntu-oci:2004 /var/cache/apt/archives/nvidia-container-runtime_${nvidia_container_runtime_version}_all.deb /opt/data/nvidia-container-runtime_${nvidia_container_runtime_version}_all.deb
for package in $NVIDIA_PACKAGES; do
    logexec ~/.cache/bin/umoci insert --image ubuntu-oci:2004 /var/cache/apt/archives/${package}_${nvidia_toolkit_version}_amd64.deb /opt/data/${package}_${nvidia_toolkit_version}_amd64.deb
done
logexec ~/.cache/bin/umoci insert --image ubuntu-oci:2004 NVIDIA-Linux-x86_64-$gpu_driver_version.run /opt/data/NVIDIA-Linux-x86_64-$gpu_driver_version.run

# retag and export to docker archive
logexec ~/.cache/bin/umoci tag --image ubuntu-oci:2004 gpu:drivers
logexec ~/.cache/bin/umoci rm --image ubuntu-oci:2004
logexec ~/.cache/bin/skopeo copy oci:ubuntu-oci:gpu:drivers docker-archive:gpu-drivers --additional-tag gpu:drivers
logexec cp -a gpu-drivers ${GITHUB_WORKSPACE}/gpu-drivers.tar

# load back into docker
logexec docker load -i ${GITHUB_WORKSPACE}/gpu-drivers.tar
logexec docker images

# run it
mkdir -p /opt/nvidia
logexec docker run --name sleeper --mount type=bind,src=/opt/nvidia,dst=/host -d --rm gpu:drivers /opt/bin/sleep infinity

# list contents for validation
logexec docker exec sleeper apt update
logexec docker exec sleeper apt install -y tree
logexec docker exec sleeper tree -L 3 /opt
logexec docker exec sleeper mv /opt/data /host/data
logexec docker exec sleeper tree -L 3 /host
logexec docker ps
logexec docker stop sleeper
for package in $NVIDIA_PACKAGES; do
    logexec sudo dpkg -i /opt/nvidia/${package}_${nvidia_toolkit_version}_amd64.deb 
done
logexec sudo dpkg -i /opt/nvidia/nvidia-container-runtime_${nvidia_container_runtime_version}_all.deb
logexec dpkg -l | grep nvidia
