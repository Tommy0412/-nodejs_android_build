#!/usr/bin/env bash
# =============================================================================
# build.sh — Build Node.js for Android ARM64 and extract artifacts
# =============================================================================
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
NODE_VERSION="${NODE_VERSION:-24.13.0}"   # Node.js version to build
NDK_VERSION="${NDK_VERSION:-r27c}"        # Android NDK version
ANDROID_API="${ANDROID_API:-24}"         # Min SDK (24 = Android 7.0)
JOBS="${JOBS:-$(nproc)}"                 # Parallel build jobs
OUTPUT_DIR="${OUTPUT_DIR:-./output}"     # Where to put artifacts
IMAGE_NAME="node-android-arm64-builder"
TERMUX_REF="${TERMUX_REF:-master}"       # Termux branch/tag for patches

echo "╔══════════════════════════════════════════════════╗"
echo "║  Node.js Android ARM64 Builder                   ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Node.js  : ${NODE_VERSION}"
echo "║  NDK      : ${NDK_VERSION}"
echo "║  API level: ${ANDROID_API}"
echo "║  Jobs     : ${JOBS}"
echo "║  Output   : ${OUTPUT_DIR}"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Build Docker image ───────────────────────────────────────────────────────
echo "▶ Building Docker image..."
docker build \
    --build-arg "NODE_VERSION=${NODE_VERSION}" \
    --build-arg "NDK_VERSION=${NDK_VERSION}" \
    --build-arg "ANDROID_API=${ANDROID_API}" \
    --build-arg "JOBS=${JOBS}" \
    --build-arg "TERMUX_REF=${TERMUX_REF}" \
    --target artifacts \
    -t "${IMAGE_NAME}:${NODE_VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    . 2>&1

echo ""
echo "▶ Extracting artifacts to ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}"

docker run --rm \
    -v "$(realpath ${OUTPUT_DIR}):/out" \
    "${IMAGE_NAME}:${NODE_VERSION}" \
    bash -c "cp -r /artifacts/. /out/ && chown -R $(id -u):$(id -g) /out"

echo ""
echo "✅ Done! Artifacts:"
find "${OUTPUT_DIR}" -type f | sort | while read f; do
    SIZE=$(du -sh "$f" | cut -f1)
    echo "   ${SIZE}  ${f}"
done

echo ""
echo "▶ Verifying libnode.so architecture..."
if command -v file &>/dev/null; then
    file "${OUTPUT_DIR}/lib/libnode.so" 2>/dev/null || echo "(file command not available)"
fi
if command -v readelf &>/dev/null; then
    readelf -h "${OUTPUT_DIR}/lib/libnode.so" 2>/dev/null | grep -E "Class|Machine|Type" || true
fi

echo ""
echo "▶ Next steps:"
echo "   1. Copy output/lib/libnode.so → app/src/main/jniLibs/arm64-v8a/"
echo "   2. Copy output/include/       → your JNI wrapper's include path"
echo "   3. Build your JNI bridge (see jni-bridge/)"
