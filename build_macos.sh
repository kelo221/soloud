#!/usr/bin/env bash
# Build libsoloud.dylib: universal (arm64 + x86_64), macOS 12.0+, Release,
# CoreAudio + Null backends, C API. Output: dist/macos/libsoloud.dylib
#
# Needs: Xcode Command Line Tools (xcode-select --install) and CMake
# (brew install cmake). Usage: ./build_macos.sh
set -euo pipefail
cd "$(dirname "$0")"
B=contrib/build-mac-universal

cmake -S contrib -B "$B" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DBUILD_SHARED_LIBS=ON -DSOLOUD_DYNAMIC=ON -DSOLOUD_STATIC=OFF -DSOLOUD_C_API=ON \
  -DSOLOUD_GENERATE_GLUE=OFF -DSOLOUD_BUILD_DEMOS=OFF -DSOLOUD_BACKEND_SDL2=OFF \
  -DSOLOUD_BACKEND_ALSA=OFF -DSOLOUD_BACKEND_OPENSLES=OFF -DSOLOUD_BACKEND_MINIAUDIO=OFF \
  -DSOLOUD_BACKEND_COREAUDIO=ON -DSOLOUD_BACKEND_NULL=ON
cmake --build "$B" -j"$(sysctl -n hw.ncpu)"

mkdir -p dist/macos
cp "$B/libsoloud.dylib" dist/macos/libsoloud.dylib
# Ad-hoc signature on both slices (the linker signs only arm64 ones).
codesign --force --sign - dist/macos/libsoloud.dylib
lipo -info dist/macos/libsoloud.dylib
otool -l dist/macos/libsoloud.dylib | grep -A4 LC_BUILD_VERSION | grep minos | sort -u
echo "Built dist/macos/libsoloud.dylib"
echo "Smoke test: python3 scripts/smoke_native_lib.py dist/macos/libsoloud.dylib --device"
