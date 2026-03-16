#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-locnguyen96}"
IMAGE_NAME="${IMAGE_NAME:-riscv-toolchain}"
UBUNTU_VERSION="${UBUNTU_VERSION:-22.04}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
PUSH="${PUSH:-false}"
BUILDER_NAME="riscv-builder"

usage() {
    echo "Usage: $0 [newlib|linux]"
    echo ""
    echo "  newlib  - Build bare-metal toolchain (riscv64-unknown-elf-*)"
    echo "  linux   - Build Linux/glibc toolchain (riscv64-unknown-linux-gnu-*)"
    echo ""
    echo "Environment variables:"
    echo "  REGISTRY        Docker registry (default: locnguyen96)"
    echo "  IMAGE_NAME      Image name (default: riscv-toolchain)"
    echo "  UBUNTU_VERSION  Ubuntu base version (default: 22.04)"
    echo "  PLATFORMS       Target platforms (default: linux/amd64,linux/arm64)"
    echo "  PUSH            Push to registry (default: false)"
    exit 1
}

TARGET="${1:-newlib}"
if [[ "$TARGET" != "newlib" && "$TARGET" != "linux" ]]; then
    echo "Error: target must be 'newlib' or 'linux'"
    usage
fi

TAG="${REGISTRY}/${IMAGE_NAME}:${TARGET}"

# Ensure buildx builder exists
if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    echo "Creating buildx builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --use
else
    docker buildx use "$BUILDER_NAME"
fi

BUILD_CMD=(
    docker buildx build
    --builder "$BUILDER_NAME"
    --platform "$PLATFORMS"
    --build-arg "TOOLCHAIN_TARGET=$TARGET"
    --build-arg "UBUNTU_VERSION=$UBUNTU_VERSION"
    -t "$TAG"
)

if [ "$PUSH" = "true" ]; then
    BUILD_CMD+=(--push)
else
    # --load only works for single platform; adjust if multi-platform
    if [[ "$PLATFORMS" == *","* ]]; then
        echo "Warning: --load not supported for multi-platform. Use PUSH=true to push to registry."
        echo "Building without output (cache only)..."
    else
        BUILD_CMD+=(--load)
    fi
fi

BUILD_CMD+=(-f Dockerfile .)

echo "Building: ${BUILD_CMD[*]}"
"${BUILD_CMD[@]}"

echo ""
echo "Done! Image: $TAG"
