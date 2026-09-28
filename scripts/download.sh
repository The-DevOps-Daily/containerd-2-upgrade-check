#!/usr/bin/env bash
# Download containerd 1.7 and 2.3 (LTS) plus runc for this machine's
# architecture into ./bin, verifying the published sha256 sums.
set -euo pipefail

OLD=1.7.36
NEW=2.3.6
NEXT=2.4.1
RUNC=1.5.2
CRICTL=1.37.0
arch=$(uname -m); case "$arch" in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; esac
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p bin/containerd-$OLD bin/containerd-$NEW bin/containerd-$NEXT

fetch() {  # version -> bin/containerd-<version>/
  local v=$1 base="https://github.com/containerd/containerd/releases/download/v$1"
  local tgz="containerd-$v-linux-$arch.tar.gz"
  curl -fsSLO "$base/$tgz"
  curl -fsSLO "$base/$tgz.sha256sum"
  sha256sum -c "$tgz.sha256sum"
  tar -xzf "$tgz" -C "bin/containerd-$v" --strip-components=1
  rm -f "$tgz" "$tgz.sha256sum"
}
fetch "$OLD"
fetch "$NEW"
fetch "$NEXT"

curl -fsSL -o bin/runc "https://github.com/opencontainers/runc/releases/download/v$RUNC/runc.$arch"
curl -fsSL -o /tmp/runc.sha256sum "https://github.com/opencontainers/runc/releases/download/v$RUNC/runc.sha256sum"
( cd bin && grep " runc.$arch\$" /tmp/runc.sha256sum | sed "s/runc.$arch/runc/" | sha256sum -c - )
chmod +x bin/runc
ctl="crictl-v$CRICTL-linux-$arch.tar.gz"
curl -fsSLO "https://github.com/kubernetes-sigs/cri-tools/releases/download/v$CRICTL/$ctl"
curl -fsSL "https://github.com/kubernetes-sigs/cri-tools/releases/download/v$CRICTL/$ctl.sha256" | awk -v f="$ctl" '{print $1"  "f}' | sha256sum -c -
tar -xzf "$ctl" -C bin crictl && rm -f "$ctl"
ls bin bin/containerd-$NEXT
