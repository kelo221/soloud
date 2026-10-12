#!/usr/bin/env bash
# Build libsoloud.so (Linux x86_64, MiniAudio + Null backends, C API) in an
# Ubuntu 20.04 container so the library is built against glibc 2.31 (it needs at most GLIBC_2.29)
# (the Steam Linux Runtime "sniper" baseline). Output: dist/linux-x64/libsoloud.so
#
# Usage: ./build_linux.sh            (needs Docker; works from Git Bash or Linux)
set -euo pipefail
cd "$(dirname "$0")"
SRC=$(pwd -W 2>/dev/null || pwd)
IMAGE=${SOLOUD_LINUX_IMAGE:-ubuntu:20.04}

MSYS_NO_PATHCONV=1 docker run --rm --platform linux/amd64 \
  -e DEBIAN_FRONTEND=noninteractive -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$SRC:/src" "$IMAGE" bash -euo pipefail -c '
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends g++ cmake make binutils >/dev/null
    cmake -S /src/contrib -B /tmp/build -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON -DSOLOUD_DYNAMIC=ON -DSOLOUD_STATIC=OFF -DSOLOUD_C_API=ON \
      -DSOLOUD_GENERATE_GLUE=OFF -DSOLOUD_BUILD_DEMOS=OFF -DSOLOUD_BACKEND_SDL2=OFF \
      -DSOLOUD_BACKEND_ALSA=OFF -DSOLOUD_BACKEND_OPENSLES=OFF -DSOLOUD_BACKEND_COREAUDIO=OFF \
      -DSOLOUD_BACKEND_MINIAUDIO=ON -DSOLOUD_BACKEND_NULL=ON
    cmake --build /tmp/build -j"$(nproc)"
    mkdir -p /src/dist/linux-x64
    cp /tmp/build/libsoloud.so /src/dist/linux-x64/libsoloud.so
    strip --strip-debug /src/dist/linux-x64/libsoloud.so
    chown "$HOST_UID:$HOST_GID" /src/dist/linux-x64/libsoloud.so 2>/dev/null || true
    echo "glibc needed: $(objdump -T /src/dist/linux-x64/libsoloud.so | grep -oE "GLIBC_[0-9.]+" | sort -uV | tail -1)"
    echo "GLIBCXX needed: $(objdump -T /src/dist/linux-x64/libsoloud.so | grep -oE "GLIBCXX_[0-9.]+" | sort -uV | tail -1)"
    objdump -p /src/dist/linux-x64/libsoloud.so | grep NEEDED
  '
