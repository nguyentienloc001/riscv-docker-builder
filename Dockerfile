# syntax=docker/dockerfile:1

# Multi-stage Dockerfile for RISC-V GNU Toolchain
# Supports both newlib (bare-metal) and linux (glibc) targets
# Builds natively on both amd64 and arm64 (no platform pinning)

ARG UBUNTU_VERSION=22.04

# =============================================================================
# Stage 1: Builder - clone and compile riscv-gnu-toolchain
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG TOOLCHAIN_TARGET=newlib

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    autotools-dev \
    curl \
    python3 \
    python3-pip \
    gawk \
    git \
    bison \
    flex \
    texinfo \
    gperf \
    libtool \
    patchutils \
    bc \
    build-essential \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    zlib1g-dev \
    libexpat1-dev \
    ninja-build \
    cmake \
    libglib2.0-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 https://github.com/riscv-collab/riscv-gnu-toolchain.git

WORKDIR /build/riscv-gnu-toolchain

RUN ./configure --prefix=/opt/riscv --enable-multilib \
    && if [ "$TOOLCHAIN_TARGET" = "linux" ]; then \
         make -j$(nproc) linux; \
       else \
         make -j$(nproc); \
       fi

# Strip debug symbols and remove unnecessary files to reduce size
RUN find /opt/riscv -type f -name '*.a' -exec strip --strip-debug {} + 2>/dev/null || true \
    && find /opt/riscv -type f -executable -exec strip --strip-unneeded {} + 2>/dev/null || true \
    && rm -rf /opt/riscv/share/doc \
              /opt/riscv/share/man \
              /opt/riscv/share/info \
              /opt/riscv/share/locale

# =============================================================================
# Stage 2: Final - clean image with only the compiled toolchain
# =============================================================================
FROM ubuntu:${UBUNTU_VERSION} AS final

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmpc3 \
    libmpfr6 \
    libgmp10 \
    zlib1g \
    libexpat1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/riscv /opt/riscv

ENV RISCV=/opt/riscv
ENV PATH="${RISCV}/bin:${PATH}"

# Verify toolchain is functional
ARG TOOLCHAIN_TARGET=newlib
RUN if [ "$TOOLCHAIN_TARGET" = "linux" ]; then \
      riscv64-unknown-linux-gnu-gcc --version; \
    else \
      riscv64-unknown-elf-gcc --version; \
    fi

WORKDIR /workspace
