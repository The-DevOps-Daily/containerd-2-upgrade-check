#!/usr/bin/env bash
# Ask registries for a manifest the way a current client does (OCI and
# schema 2 first, schema 1 last) and print the media type they return.
# A schema 1 answer means the tag exists only in that format.
set -uo pipefail

accept="application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.v1+prettyjws"

probe() { # registry repository tag
  local reg=$1 repo=$2 tag=$3 auth=()
  if [ "$reg" = registry-1.docker.io ]; then
    local token
    token=$(curl -fsS "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$repo:pull" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')
    auth=(-H "Authorization: Bearer $token")
  fi
  curl -sL -o /dev/null -w "$reg/$repo:$tag  %{http_code}  %{content_type}\n" "${auth[@]}" -H "Accept: $accept" "https://$reg/v2/$repo/manifests/$tag"
}

probe registry-1.docker.io library/busybox 1.24
probe registry-1.docker.io library/busybox 1.36.0
probe gcr.io google-containers/busybox 1.24
probe gcr.io google-containers/pause 0.8.0
probe quay.io coreos/etcd v2.2.5
