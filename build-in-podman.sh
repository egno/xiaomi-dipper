#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

IMAGE="${PODMAN_IMAGE:-xiaomi-dipper-build}"
FLASHABLE=0

usage() {
    cat <<'EOF'
Usage: build-in-podman.sh [--flashable]

Build dipper device images inside Podman (Ubuntu 22.04).

  --flashable   Also build boot.img, recovery.img, and system.img via prepare-fake-ota

Environment:
  PODMAN_IMAGE  Container image name (default: xiaomi-dipper-build)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
    --flashable) FLASHABLE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

if ! command -v podman >/dev/null 2>&1; then
    echo "podman is required but not installed." >&2
    exit 1
fi

ensure_podman() {
    if ! podman ps >/dev/null 2>&1; then
        podman machine start podman-machine-default 2>&1 || podman machine start 2>&1 || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            podman ps >/dev/null 2>&1 && return 0
            sleep 2
        done
        echo "Podman is not reachable. Try: podman machine stop && podman machine start" >&2
        exit 1
    fi
}

ensure_podman

# Android NDK toolchains are x86_64 Linux binaries; run amd64 containers on arm64 Macs.
PODMAN_PLATFORM=()
case "$(uname -m)" in
arm64|aarch64) PODMAN_PLATFORM=(--platform linux/amd64) ;;
esac

# Linux kernel builds require a case-sensitive tree; macOS bind mounts are usually not.
WORKDIR_VOLUME="${PODMAN_WORKDIR_VOLUME:-xiaomi-dipper-workdir}"
podman volume exists "$WORKDIR_VOLUME" >/dev/null 2>&1 || podman volume create "$WORKDIR_VOLUME" >/dev/null

seed_workdir_volume() {
    local marker="downloads/.seeded-from-host"
    if podman run --rm "${PODMAN_PLATFORM[@]}" -v "${WORKDIR_VOLUME}:/workdir:Z" "$IMAGE" \
        test -f "/workdir/${marker}"; then
        return 0
    fi
    if [ -d "$HERE/workdir/downloads" ]; then
        echo "Seeding Podman workdir volume from host (one-time)..."
        podman run --rm "${PODMAN_PLATFORM[@]}" \
            -v "$HERE/workdir:/host:Z" \
            -v "${WORKDIR_VOLUME}:/workdir:Z" \
            "$IMAGE" \
            bash -lc '
                cp -a /host/. /workdir/
                rm -rf /workdir/downloads/kernel-xiaomi-sdm845 /workdir/downloads/KERNEL_OBJ
                chmod +x /workdir/downloads/arm-linux-androideabi-4.9/arm-linux-androideabi/bin/as 2>/dev/null || true
                touch /workdir/downloads/.seeded-from-host
            '
    fi
}

PODMAN_MOUNTS=(
    -v "$HERE:/src:Z"
    -v "${WORKDIR_VOLUME}:/src/workdir:Z"
)

echo "Building container image ${IMAGE}..."
podman build "${PODMAN_PLATFORM[@]}" -t "$IMAGE" -f "$HERE/Containerfile" "$HERE"

seed_workdir_volume

mkdir -p out

echo "Building device tarball..."
podman run --rm "${PODMAN_PLATFORM[@]}" \
    "${PODMAN_MOUNTS[@]}" \
    -w /src \
    "$IMAGE" \
    ./build.sh -b workdir -o out

if [ "$FLASHABLE" = "1" ]; then
    echo "Building flashable images..."
    podman run --rm "${PODMAN_PLATFORM[@]}" \
        "${PODMAN_MOUNTS[@]}" \
        -w /src \
        "$IMAGE" \
        bash -lc '
            set -xe
            [ -f build/build.sh ] || ./build.sh -c
            DEVICE="$(source deviceinfo && echo "$deviceinfo_codename")"
            ./build/prepare-fake-ota.sh "out/device_${DEVICE}.tar.xz" ota
            ./build/system-image-from-ota.sh ota/ubuntu_command out
        '
fi

echo
echo "Build artifacts:"
ls -lh "$HERE/out/" 2>/dev/null || true
