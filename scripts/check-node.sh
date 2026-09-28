#!/usr/bin/env bash
# Check one node for the things that change when containerd 1.7 becomes 2.x.
# Read-only. Run it as root on the node. Override the defaults with
# CONTAINERD_CONFIG, CONTAINERD_ADDRESS and CTR if your paths differ.
set -uo pipefail

config=${CONTAINERD_CONFIG:-/etc/containerd/config.toml}
address=${CONTAINERD_ADDRESS:-/run/containerd/containerd.sock}
ctr=${CTR:-ctr}

echo "== containerd version"
$ctr --address "$address" version 2>/dev/null | sed -n '/Server:/,$p' | grep -E "Version|Revision" || echo "cannot reach containerd at $address"

echo
echo "== config: $config"
if [ -f "$config" ]; then
  echo "config version: $(sed -n 's/^version *= *\([0-9]*\).*/\1/p' "$config" | head -n 1)"
  grep -q 'registry.mirrors' "$config" && echo "WARN inline registry.mirrors: deprecated; move to config_path and hosts.toml files"
  grep -q 'io.containerd.runtime.v1.linux' "$config" && echo "WARN runtime v1 section: removed in 2.0; containerd 2.x ignores it"
  grep -q 'io.containerd.snapshotter.v1.aufs\|snapshotter *= *"aufs"' "$config" && echo "WARN aufs snapshotter: removed in 2.0; use overlayfs"
else
  echo "no config file (containerd uses built-in defaults)"
fi

echo
echo "== deprecations containerd has already seen (1.7.x and later)"
$ctr --address "$address" deprecations list 2>/dev/null || echo "not available on this version"

echo
echo "== images that were converted from schema 1 (they keep working; pulling them again on 2.x fails)"
found=0
for ns in $($ctr --address "$address" namespaces ls -q 2>/dev/null); do
  while read -r ref; do
    [ -n "$ref" ] && { echo "$ns  $ref"; found=1; }
  done < <($ctr --address "$address" -n "$ns" images ls 2>/dev/null | awk '/converted-docker-schema1/ {print $1}')
done
[ "$found" = 0 ] && echo "none"
