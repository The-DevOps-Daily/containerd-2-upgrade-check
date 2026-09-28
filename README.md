# containerd-2-upgrade-check

What actually changes when a node moves from containerd 1.7 to 2.x, recorded by running containerd 1.7.36, then 2.3.6, then 2.4.1 against the same state directory and the same old config, the way an in-place node upgrade does. Plus a read-only script to check a real node.

```bash
sudo scripts/check-node.sh
```

## Check a node

`scripts/check-node.sh` is read-only. Run it as root on a node. It reports the containerd version, the config version, deprecated config sections (inline registry mirrors, runtime v1, aufs), the deprecations containerd has already recorded (`ctr deprecations list`, 1.7.x and later), and every image that was converted from Docker schema 1. Override the paths with `CONTAINERD_CONFIG`, `CONTAINERD_ADDRESS` and `CTR`.

On Kubernetes, list the runtime version of every node:

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,RUNTIME:.status.nodeInfo.containerRuntimeVersion
```

## Reproduce the upgrade

```bash
scripts/download.sh   # containerd 1.7.36, 2.3.6, 2.4.1, runc 1.5.2, crictl 1.37.0; sha256-checked
scripts/demo.sh       # needs sudo; everything lives under /tmp/ctd-demo
```

`demo.sh` starts each version in turn with [`configs/old-node-config.toml`](configs/old-node-config.toml) (config version 2, CRI settings in the old sections, an inline `docker.io` mirror and a leftover runtime v1 section) and records to `runs/`:

- `ctr deprecations list` before and after
- a CRI image pull with `crictl`, and how many requests reached the configured `docker.io` mirror (a local server from `scripts/mirror-logger.py` that logs requests and answers 404)
- on 1.7: pulling a schema 1 image (`docker.io/library/busybox:1.24`)
- on 2.x: whether that image is still there, and pulling it again
- the daemon's warnings, and `containerd config migrate` from 2.3.6 and 2.4.1

## What the recorded runs show

- **The version 2 config still loads.** 2.3.6 and 2.4.1 migrate it at startup and log `Configuration migrated from version 2, use containerd config migrate to avoid migration`. `config migrate` writes `version = 4` and carries the dead runtime v1 section and the inline mirrors into the new file.
- **Inline mirrors still work on all three versions.** The mirror received 5 requests per pull on 1.7.36, 2.3.6 and 2.4.1. The deprecation says they will be removed in v2.1 (on 1.7.36), v2.4 (on 2.3.6) and v2.7 (on 2.4.1). On 2.x they also switch image pulls to "local image pull mode" instead of the transfer service.
- **Schema 1 is the real break, and it is delayed.** The image pulled on 1.7 (converted, labelled `io.containerd.image/converted-docker-schema1`) is still there after the upgrade. Pulling it again, or pulling any other schema 1 image, fails on 2.3.6 and 2.4.1 with `schema 1 image manifests are no longer supported: invalid argument`. So the failure shows up on the next fresh node, not the upgraded one.

Recorded on a Raspberry Pi 4 (arm64); the schema 1 images are amd64 only, so they are pulled with `--platform linux/amd64` and not run.

## License

MIT
