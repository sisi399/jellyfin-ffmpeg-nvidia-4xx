#!/bin/bash

SCRIPT_REPO="https://skia.googlesource.com/third_party/libiconv"
SCRIPT_COMMIT="v1.18"
SCRIPT_TAGFILTER="v?.*"

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    # iconv is macOS built-in
    [[ $TARGET == mac* ]] && return 0

    git-mini-clone "$SCRIPT_REPO" "$SCRIPT_COMMIT" iconv
    cd iconv

    cat <<EOF > ./.gitmodules
[subcheckout "gnulib"]
	url = https://github.com/coreutils/gnulib.git
	path = gnulib
EOF

    ./gitsub.sh pull
    ./gitsub.sh checkout gnulib e9c1d94f58eaacee919bb2015da490b980a5eedf

    # No automake 1.17 packaged anywhere yet.
    sed -i 's/-1.17/-1.16/' Makefile.devel

    (unset CC CFLAGS GMAKE && ./autogen.sh)

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --enable-extra-encodings
        --disable-shared
        --enable-static
        --with-pic
    )

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(
            --host="$FFBUILD_TOOLCHAIN"
        )
    else
        echo "Unknown target"
        return -1
    fi

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install
}

ffbuild_configure() {
    echo --enable-iconv
}

ffbuild_unconfigure() {
    echo --disable-iconv
}
