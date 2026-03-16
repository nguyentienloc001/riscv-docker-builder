# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based builder for the RISC-V GNU toolchain. Uses Docker buildx for multi-platform builds (linux/amd64 and linux/arm64) with multi-stage builds to minimize final image size.

## Build Commands

```bash
# Build bare-metal (newlib) toolchain - local single platform
./build.sh newlib

# Build Linux/glibc toolchain - local single platform
./build.sh linux

# Build for single platform (e.g., arm64 only for M1 Mac)
PLATFORMS=linux/arm64 ./build.sh newlib

# Build multi-platform and push to registry
PUSH=true ./build.sh newlib
PUSH=true ./build.sh linux
```

## Architecture

Single `Dockerfile` with two stages controlled by `ARG TOOLCHAIN_TARGET` (newlib or linux):

- **Stage 1 (builder)**: Ubuntu base with full build dependencies. Clones riscv-gnu-toolchain, configures with `--enable-multilib`, compiles. Strips binaries and removes docs to reduce size.
- **Stage 2 (final)**: Clean Ubuntu with only runtime libraries (libmpc3, libmpfr6, libgmp10, zlib1g, libexpat1). Copies `/opt/riscv` from builder. Verifies the toolchain works.

No `--platform` pinning in FROM lines — the toolchain compiles from source so it builds natively on both amd64 and arm64 (avoids Rosetta emulation overhead on M1).

## Key Details

- `--load` only works for single-platform builds; multi-platform requires `PUSH=true`
- Toolchain compilation takes 1-3 hours depending on hardware
- Output binaries: `riscv64-unknown-elf-*` (newlib) or `riscv64-unknown-linux-gnu-*` (linux)
- Toolchain installs to `/opt/riscv` inside the container
- Build script creates/reuses a buildx builder named `riscv-builder`
- Registry defaults to `locnguyen96`, configurable via `REGISTRY` env var
