#!/usr/bin/env bash
# Build libsoloud.so for Android (arm64-v8a and armeabi-v7a; OpenSL ES + Null
# backends, C API, static libc++, 16 KiB page alignment) with the Android NDK in
# an Ubuntu container. The NDK is downloaded once into the Docker volume
# "soloud-android-ndk".
# Output: dist/android/<abi>/libsoloud.so
#
# Usage: ./build_android.sh          (needs Docker; works from Git Bash or Linux)
# Environment: SOLOUD_NDK_VERSION (default r27d), SOLOUD_ANDROID_API (default 23),
#              SOLOUD_ANDROID_ABIS (default "arm64-v8a armeabi-v7a")
set -euo pipefail
cd "$(dirname "$0")"
SRC=$(pwd -W 2>/dev/null || pwd)
NDK_VERSION=${SOLOUD_NDK_VERSION:-r27d}
API=${SOLOUD_ANDROID_API:-23}
ABIS=${SOLOUD_ANDROID_ABIS:-arm64-v8a armeabi-v7a}

MSYS_NO_PATHCONV=1 docker run --rm --platform linux/amd64 \
  -e DEBIAN_FRONTEND=noninteractive -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -e NDK_VERSION="$NDK_VERSION" -e API="$API" -e ABIS="$ABIS" \
  -v soloud-android-ndk:/ndk -v "$SRC:/src" ubuntu:22.04 bash -euo pipefail -c '
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends cmake ninja-build unzip curl ca-certificates file >/dev/null
    NDK=/ndk/android-ndk-$NDK_VERSION
    if [ ! -f "$NDK/build/cmake/android.toolchain.cmake" ]; then
      curl -fsSL -o /tmp/ndk.zip "https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux.zip"
      unzip -q /tmp/ndk.zip -d /ndk
      rm /tmp/ndk.zip
    fi
    echo "NDK: $(grep Pkg.Revision "$NDK/source.properties")"
    for ABI in $ABIS; do
      cmake -G Ninja -S /src/contrib -B /tmp/build-$ABI -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API -DANDROID_STL=c++_static \
        -DCMAKE_SHARED_LINKER_FLAGS="-llog -landroid -Wl,-z,max-page-size=16384" \
        -DBUILD_SHARED_LIBS=ON -DSOLOUD_DYNAMIC=ON -DSOLOUD_STATIC=OFF -DSOLOUD_C_API=ON \
        -DSOLOUD_GENERATE_GLUE=OFF -DSOLOUD_BUILD_DEMOS=OFF -DSOLOUD_BACKEND_SDL2=OFF \
        -DSOLOUD_BACKEND_ALSA=OFF -DSOLOUD_BACKEND_COREAUDIO=OFF -DSOLOUD_BACKEND_MINIAUDIO=OFF \
        -DSOLOUD_BACKEND_OPENSLES=ON -DSOLOUD_BACKEND_NULL=ON >/dev/null
      cmake --build /tmp/build-$ABI
      mkdir -p /src/dist/android/$ABI
      "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-debug \
        -o /src/dist/android/$ABI/libsoloud.so /tmp/build-$ABI/libsoloud.so
      chown -R "$HOST_UID:$HOST_GID" /src/dist/android 2>/dev/null || true
      file /src/dist/android/$ABI/libsoloud.so
    done
  '
