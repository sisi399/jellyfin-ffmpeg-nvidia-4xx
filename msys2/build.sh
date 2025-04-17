#!/bin/bash
set -xe
cd "$(dirname "$0")"
export BUILDER_ROOT="$(pwd)"
export FFBUILD_PREFIX="/clang64/ffbuild"
export CMAKE_POLICY_VERSION_MINIMUM="3.5"

arch="x86_64"
TARGET="win64-clang"
VARIANT="gpl"

# Copy libc++ to our prefix folder
mkdir -p /clang64/ffbuild/lib
cp /clang64/lib/libc++.a /clang64/ffbuild/lib/libc++.a

cd "$BUILDER_ROOT"/PKGBUILD
for pkg in *; do
    if [ -d "$pkg" ]; then
        echo "Installing $pkg"
        cd "$pkg"

        (MINGW_ARCH=clang64 makepkg-mingw -sLfi --noconfirm --skippgpcheck) || exit $?

        cd ..
      fi
done

cd "$BUILDER_ROOT"
cd ..
if [[ -f "debian/patches/series" ]]; then
    ln -s debian/patches patches
    quilt push -a
fi

PKG_CONFIG_PATH=/clang64/ffbuild/lib/pkgconfig ./configure --cc=clang \
    --pkg-config-flags=--static \
    --extra-cflags=-I/clang64/ffbuild/include \
    --extra-ldflags=-L/clang64/ffbuild/lib \
    --prefix=/clang64/ffbuild/jellyfin-ffmpeg \
    --extra-version=Jellyfin \
    --disable-ffplay \
    --disable-debug \
    --disable-doc \
    --disable-sdl2 \
    --enable-lto=thin \
    --enable-gpl \
    --enable-version3 \
    --enable-schannel \
    --enable-iconv \
    --enable-libxml2 \
    --enable-zlib \
    --enable-lzma \
    --enable-gmp \
    --enable-chromaprint \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libfontconfig \
    --enable-libharfbuzz \
    --enable-libass \
    --enable-libbluray \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libtheora \
    --enable-libvorbis \
    --enable-libopenmpt \
    --enable-libwebp \
    --enable-libvpx \
    --enable-libzimg \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libsvtav1 \
    --enable-libdav1d \
    --enable-libfdk-aac \
    --enable-opencl \
    --enable-dxva2 \
    --enable-d3d11va \
    --enable-d3d12va \
    --enable-amf \
    --enable-libvpl \
    --enable-ffnvcodec \
    --enable-cuda \
    --enable-cuda-llvm \
    --enable-cuvid \
    --enable-nvdec \
    --enable-nvenc

make -j$(nproc) V=1

# We have to manually match lines to get version as there will be no dpkg-parsechangelog on msys2
PKG_VER=0.0.0
while IFS= read -r line; do
    if [[ $line == jellyfin-ffmpeg* ]]; then
        if [[ $line =~ \(([^\)]+)\) ]]; then
            PKG_VER="${BASH_REMATCH[1]}"
            break
        fi
    fi
done < "$BUILDER_ROOT"/../debian/changelog

PKG_NAME="jellyfin-ffmpeg_${PKG_VER}_portable_${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"
ARTIFACTS_PATH="$BUILDER_ROOT"/artifacts
OUTPUT_FNAME="${PKG_NAME}.zip"
cd "$BUILDER_ROOT"
mkdir -p artifacts
mv ../ffmpeg.exe ./
mv ../ffprobe.exe ./
zip -9 -r "${ARTIFACTS_PATH}/${OUTPUT_FNAME}" ffmpeg.exe ffprobe.exe
cd "$BUILDER_ROOT"/..

if [[ -n "$GITHUB_ACTIONS" ]]; then
    echo "build_name=${BUILD_NAME}" >> "$GITHUB_OUTPUT"
    echo "${OUTPUT_FNAME}" > "${ARTIFACTS_PATH}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}.txt"
fi
