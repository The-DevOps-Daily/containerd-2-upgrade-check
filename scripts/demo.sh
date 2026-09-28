#!/usr/bin/env bash
# Run containerd 1.7, then 2.3, then 2.4 against the same state directory and
# the same old config, the way in-place node upgrades do, and record what each
# version says. Needs root for the daemons. Nothing touches the host's own
# containerd: everything lives under /tmp/ctd-demo.
set -uo pipefail

OLD=1.7.36
NEW=2.3.6
NEXT=2.4.1
root="$(cd "$(dirname "$0")/.." && pwd)"
demo=/tmp/ctd-demo
sock=$demo/containerd.sock
out="$root/runs"
cfg="$root/configs/old-node-config.toml"
export PATH="$root/bin:$PATH"   # runc

rm -rf "$out"; mkdir -p "$out"
rec() { # name, then the command; prints and records the command and its output
  local name=$1; shift
  { echo "\$ $*"; "$@" 2>&1; echo "[exit $?]"; } | tee "$out/$name.txt"
}
ctr() { sudo "$root/bin/containerd-$1/ctr" --address "$sock" "${@:2}"; }
crictl() { sudo "$root/bin/crictl" --runtime-endpoint "unix://$sock" --image-endpoint "unix://$sock" "$@"; }
# ctr pull draws a progress bar; keep only its last lines and its exit code
pull_quiet() { local v=$1; shift; ctr "$v" -n demo images pull --platform linux/amd64 "$@" >"$demo/pull.log" 2>&1; local ec=$?; tail -n 2 "$demo/pull.log"; return $ec; }

start() { # version
  sudo rm -f "$sock"
  sudo env PATH="$PATH" "$root/bin/containerd-$1/containerd" --config "$cfg" \
    --address "$sock" --root "$demo/root" --state "$demo/state" \
    >"$out/daemon-$1.log" 2>&1 &
  daemon=$!
  for _ in $(seq 1 30); do [ -S "$sock" ] && return 0; sleep 1; done
  echo "containerd $1 did not start; see runs/daemon-$1.log"; return 1
}
stop() { sudo kill "$daemon"; wait "$daemon" 2>/dev/null; sleep 1; }  # sudo passes the signal on
mirror_report() { echo "requests the docker.io mirror received: $(wc -l <"$demo/mirror.log")"; head -n 3 "$demo/mirror.log"; }

sudo rm -rf "$demo"; mkdir -p "$demo"; : >"$demo/mirror.log"
python3 "$root/scripts/mirror-logger.py" 5055 "$demo/mirror.log" & mirror=$!

rec 00-versions sh -c "for v in $OLD $NEW $NEXT; do $root/bin/containerd-\$v/containerd --version; done"

step=1
for v in "$OLD" "$NEW" "$NEXT"; do
  start "$v" || continue
  : >"$demo/mirror.log"
  rec "$step-$v-a-deprecations" ctr "$v" deprecations list
  rec "$step-$v-b-crictl-pull" crictl pull "docker.io/library/busybox:1.3$((5 + step)).0"
  rec "$step-$v-c-mirror" mirror_report
  if [ "$v" = "$OLD" ]; then
    rec "$step-$v-d-pull-schema1" pull_quiet "$v" docker.io/library/busybox:1.24
  else
    rec "$step-$v-d-images-kept" ctr "$v" -n demo images ls
    rec "$step-$v-e-pull-schema1" pull_quiet "$v" docker.io/library/busybox:1.24
  fi
  rec "$step-$v-f-deprecations-after" ctr "$v" deprecations list
  stop "$v"
  grep -iE "level=(warn|error|fatal)" "$out/daemon-$v.log" | grep -v "cni" | cut -c1-400 >"$out/$step-$v-g-daemon-warnings.txt"
  step=$((step + 1))
done

rec 9-config-migrate-$NEW "$root/bin/containerd-$NEW/containerd" --config "$cfg" config migrate
rec 9-config-migrate-$NEXT "$root/bin/containerd-$NEXT/containerd" --config "$cfg" config migrate
kill "$mirror"
sudo rm -rf "$demo"
echo "done: recorded in runs/"
