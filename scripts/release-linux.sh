#!/usr/bin/env bash
#
# release-linux.sh — build the Linux release archives inside WSL.
#
# Invoked by scripts/release.ps1 (-Linux) via:
#   wsl -d Ubuntu -- bash -lc "STREAMFIND_RELEASE_VERSION=<ver> STREAMFIND_RELEASE_DIR=<tmp-release-output-as-/mnt/c> bash /mnt/c/.../scripts/release-linux.sh"
#
# Design points:
#  - The WSL-ext4 filesystem is used for build trees ($HOME/streamfind-release)
#    because building inside /mnt/c (drivefs) is 10-50x slower. Sources are
#    read from the /mnt/c mount; build output + cargo target dir live on ext4.
#  - Produces, into $STREAMFIND_RELEASE_DIR:
#      streamfind-core-cpp-<ver>-Linux-<arch>.tgz   (CPack TGZ)
#      streamfind-rust-<ver>-Linux-<arch>.tgz       (assembled)
#  - Requires: cmake, ninja-build, g++ (or clang), and a Rust toolchain.
#    One-time setup:
#      sudo apt-get update && sudo apt-get install -y cmake ninja-build g++ openbabel pkg-config curl unzip
#      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
#
# The archive naming uses the same schema as the Windows side so release
# tooling (and sha256sums.txt on the Windows side) treat them uniformly.
# The full NTA conformance test is skipped by default; set
# STREAMFIND_RUN_NTA_CONFORMANCE=1 to request it explicitly.

set -euo pipefail

VERSION="${STREAMFIND_RELEASE_VERSION:?STREAMFIND_RELEASE_VERSION is required}"
OUT_DIR="${STREAMFIND_RELEASE_DIR:?STREAMFIND_RELEASE_DIR is required}"

# Repo root as seen from inside WSL (/mnt/c/Users/.../streamfind).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Fast ext4 build area.
WORK="$HOME/streamfind-release/$VERSION"
mkdir -p "$WORK"
echo "[release-linux] version=$VERSION out=$OUT_DIR work=$WORK"

# Tool detection (WSL Ubuntu): PATH first, then common locations.
require_tool() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        echo "[release-linux] missing required tool: $name" >&2
        echo "  One-time setup:" >&2
        echo "    sudo apt-get update && sudo apt-get install -y cmake ninja-build g++ openbabel pkg-config curl unzip" >&2
        exit 1
    fi
}

assert_distribution_payload() {
    local root="$1"
    local license_payload="${2:-licenses}"
    test -f "$root/NOTICE.md" || { echo "[release-linux] missing NOTICE.md" >&2; exit 1; }
    test -f "$root/LICENSE.md" || { echo "[release-linux] missing LICENSE.md" >&2; exit 1; }
    if [ "$license_payload" = "licenses" ]; then
        test -d "$root/licenses" || { echo "[release-linux] missing licenses/" >&2; exit 1; }
    else
        test -f "$root/$license_payload" || { echo "[release-linux] missing $license_payload" >&2; exit 1; }
    fi
    shopt -s globstar nullglob
    local path rel
    for path in "$root"/**; do
        rel="${path#"$root/"}"
        case "$rel" in
            *ClearCore*|*ProteoWizard*|*msconvert*|*baf2sql*|*WinDbg*|*CDB*|*vendor-sdk*|*vendor-dll*|*confidential*|*oracle*)
                echo "[release-linux] development-only material in package: $rel" >&2
                exit 1
                ;;
        esac
    done
}

assert_archive_payload() {
    local archive="$1"
    local license_payload="${2:-licenses}"
    local listing="$WORK/$(basename "$archive").list"
    tar -tzf "$archive" > "$listing"
    grep -Eq '(^|/)NOTICE[.]md$' "$listing" || { echo "[release-linux] archive missing NOTICE.md" >&2; exit 1; }
    grep -Eq '(^|/)LICENSE[.]md$' "$listing" || { echo "[release-linux] archive missing LICENSE.md" >&2; exit 1; }
    if [ "$license_payload" = "licenses" ]; then
        grep -Eq '(^|/)licenses/' "$listing" || { echo "[release-linux] archive missing licenses/" >&2; exit 1; }
    else
        grep -Eq "(^|/)$license_payload$" "$listing" || { echo "[release-linux] archive missing $license_payload" >&2; exit 1; }
    fi
}
for tool in cmake ninja g++ cargo obabel; do require_tool "$tool"; done

ARCH="$(uname -m)"   # x86_64 / aarch64
echo "[release-linux] arch=$ARCH"

# ---------------------------------------------------------------------------
# C++ core
# ---------------------------------------------------------------------------
if [ "${STREAMFIND_BUILD_CORE:-1}" != "0" ]; then
    echo "[release-linux] building C++ core (Release)..."
    CORE_BUILD="$WORK/core-build"
    rm -rf "$CORE_BUILD"
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DSTREAMFIND_BUILD_TESTS=ON \
        -DSTREAMFIND_BUILD_SHARED=OFF \
        -B "$CORE_BUILD" \
        -S "$REPO_ROOT/core"
    cmake --build "$CORE_BUILD" -j "$(nproc)"

    if [ "${STREAMFIND_RUN_TESTS:-1}" != "0" ]; then
        echo "[release-linux] running fast C++ tests..."
        (cd "$CORE_BUILD" && ctest -C Release -E wastewater -LE reader-interface --output-on-failure)
    fi

    echo "[release-linux] packaging C++ core (CPack TGZ)..."
    (cd "$CORE_BUILD" && cpack -G TGZ -C Release -B "$OUT_DIR")
    CORE_TAR="$OUT_DIR/streamfind-core-cpp-$VERSION-Linux-$ARCH.tar.gz"
    CORE_TGZ="$OUT_DIR/streamfind-core-cpp-$VERSION-Linux-$ARCH.tgz"
    if [ -f "$CORE_TAR" ]; then
        mv -f "$CORE_TAR" "$CORE_TGZ"
    fi
    assert_archive_payload "$CORE_TGZ" licenses
fi

# ---------------------------------------------------------------------------
# Rust workspace
# ---------------------------------------------------------------------------
if [ "${STREAMFIND_BUILD_RUST:-1}" != "0" ]; then
    echo "[release-linux] building Rust workspace (release, stripped)..."
    export CARGO_TARGET_DIR="$WORK/rust-target"
    (cd "$REPO_ROOT/rust" && cargo build --release --workspace --exclude streamfind-rust-test-support)

    if [ "${STREAMFIND_RUN_TESTS:-1}" != "0" ]; then
        echo "[release-linux] running Rust tests..."
        if [ "${STREAMFIND_RUN_NTA_CONFORMANCE:-0}" = "1" ]; then
            (cd "$REPO_ROOT/rust" && cargo test --workspace)
        else
            echo "[release-linux] skipping full NTA conformance (set STREAMFIND_RUN_NTA_CONFORMANCE=1 to run it)"
            (cd "$REPO_ROOT/rust" && cargo test --workspace -- --skip nta_quantized_wastewater_pipeline)
        fi
    fi

    STAGING="$WORK/rust-staging"
    rm -rf "$STAGING"
    mkdir -p "$STAGING/bin" "$STAGING/share/streamfind"
    cp "$CARGO_TARGET_DIR/release/streamfind-rust-cli" "$STAGING/bin/"
    cp "$CARGO_TARGET_DIR/release/streamfind-rust-mcp"  "$STAGING/bin/"
    cp "$REPO_ROOT/semantic/generated/catalogue.duckdb" "$STAGING/share/streamfind/"
    cp "$REPO_ROOT/LICENSE.md" "$STAGING/"
    cp "$REPO_ROOT/NOTICE.md" "$STAGING/"
    cp "$REPO_ROOT/rust/LICENSES.md" "$STAGING/"
    assert_distribution_payload "$STAGING" LICENSES.md

    RUST_TGZ="$OUT_DIR/streamfind-rust-$VERSION-Linux-$ARCH.tgz"
    (cd "$STAGING" && tar czf "$RUST_TGZ" .)
    assert_archive_payload "$RUST_TGZ" LICENSES.md
    echo "[release-linux] rust archive: $(basename "$RUST_TGZ") ($(du -h "$RUST_TGZ" | cut -f1))"
fi

echo "[release-linux] done."
ls -lh "$OUT_DIR" | grep -i "Linux-" || true