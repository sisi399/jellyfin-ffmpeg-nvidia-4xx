#!/bin/bash

SCRIPT_REPO="https://gitlab.freedesktop.org/xorg/lib/libxxf86vm.git"
SCRIPT_COMMIT="b7d0126604e74871844fcecda04d45bb25988a2c"

ffbuild_enabled() {
    [[ $TARGET != linux* ]] && return -1
    return 0
}

ffbuild_dockerbuild() {
    git-mini-clone "$SCRIPT_REPO" "$SCRIPT_COMMIT" libxxf86vm
    cd libxxf86vm

    autoreconf -i

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --enable-shared
        --disable-static
        --with-pic
    )

    if [[ $TARGET == linuxarm64 ]]; then
        myconf+=(
            --disable-malloc0returnsnull
        )
    fi

    if [[ $TARGET == linux* ]]; then
        myconf+=(
            --host="$FFBUILD_TOOLCHAIN"
        )
    else
        echo "Unknown target"
        return -1
    fi

    export CFLAGS="$RAW_CFLAGS"
    export LDFLAFS="$RAW_LDFLAGS"

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install

    gen-implib "$FFBUILD_PREFIX"/lib/{libXxf86vm.so.1,libXxf86vm.a}
    rm "$FFBUILD_PREFIX"/lib/libXxf86vm{.so*,.la}
}
