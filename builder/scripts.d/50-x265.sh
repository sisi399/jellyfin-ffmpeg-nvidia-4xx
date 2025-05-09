#!/bin/bash

SCRIPT_REPO="https://bitbucket.org/multicoreware/x265_git.git"
SCRIPT_COMMIT="fa2770934b8f3d88aa866c77f27cb63f69a9ed39"

ffbuild_enabled() {
    [[ $VARIANT == lgpl* ]] && return -1
    return 0
}

ffbuild_dockerbuild() {
    git clone "$SCRIPT_REPO" x265
    cd x265
    git checkout "$SCRIPT_COMMIT"

    # Unbreak build compat with CMake 4.0+
    if [[ $TARGET == mac* ]]; then
        gsed -i 's/CMP0025 OLD/CMP0025 NEW/g' source/CMakeLists.txt
        gsed -i 's/CMP0054 OLD/CMP0054 NEW/g' source/CMakeLists.txt
        gsed -i 's/STREQUAL \"Clang\"/MATCHES \"Clang\"/g' source/CMakeLists.txt
    else
        sed -i 's/CMP0025 OLD/CMP0025 NEW/g' source/CMakeLists.txt
        sed -i 's/CMP0054 OLD/CMP0054 NEW/g' source/CMakeLists.txt
        sed -i 's/STREQUAL \"Clang\"/MATCHES \"Clang\"/g' source/CMakeLists.txt
    fi

    # Fix naming conflicts: https://bitbucket.org/multicoreware/x265_git/issues/984/illegal-instruction-neon_dotprod-crashes
    if [[ $TARGET == mac* ]]; then
        gsed -i 's/interp8_horiz_pp_dotprod/interp8_horiz_pp_dotprod_i8mm/g' source/common/aarch64/filter-neon-i8mm.cpp
        gsed -i 's/interp8_horiz_ps_dotprod/interp8_horiz_ps_dotprod_i8mm/g' source/common/aarch64/filter-neon-i8mm.cpp
    else
        sed -i 's/interp8_horiz_pp_dotprod/interp8_horiz_pp_dotprod_i8mm/g' source/common/aarch64/filter-neon-i8mm.cpp
        sed -i 's/interp8_horiz_ps_dotprod/interp8_horiz_ps_dotprod_i8mm/g' source/common/aarch64/filter-neon-i8mm.cpp
    fi

    local common_config=(
        -DCMAKE_INSTALL_PREFIX="$FFBUILD_PREFIX"
        -DCMAKE_BUILD_TYPE=Release
        -DENABLE_SHARED=OFF
        -DENABLE_CLI=OFF
        -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy
        -DENABLE_ALPHA=ON
    )

    if [[ $TARGET != mac* ]]; then
        common_config+=(
            -DCMAKE_TOOLCHAIN_FILE="$FFBUILD_CMAKE_TOOLCHAIN"
        )
    fi

    if [[ $TARGET != *32 ]]; then
        mkdir 8bit 10bit 12bit
        cmake "${common_config[@]}" -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_HDR10_PLUS=ON -DMAIN12=ON -S source -B 12bit &
        cmake "${common_config[@]}" -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_HDR10_PLUS=ON -S source -B 10bit &
        cmake "${common_config[@]}" -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -S source -B 8bit &
        wait

        cat >Makefile <<"EOF"
all: 12bit/libx265.a 10bit/libx265.a 8bit/libx265.a

%/libx265.a:
	$(MAKE) -C $(subst /libx265.a,,$@)

.PHONY: all
EOF

        make -j$(nproc)

        cd 8bit
        mv ../12bit/libx265.a ../8bit/libx265_main12.a
        mv ../10bit/libx265.a ../8bit/libx265_main10.a
        mv libx265.a libx265_main.a

        if [[ $TARGET == mac* ]]; then
            libtool -static -o libx265.a libx265_main.a libx265_main10.a libx265_main12.a 2>/dev/null
        else
        ${FFBUILD_CROSS_PREFIX}ar -M <<EOF
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
EOF
        fi
    else
        mkdir 8bit
        cd 8bit
        cmake "${common_config[@]}" ../source
        make -j$(nproc)
    fi

    make install

    if [[ $TARGET != mac* ]]; then
        echo "Libs.private: -lstdc++" >> "$FFBUILD_PREFIX"/lib/pkgconfig/x265.pc
    fi
}

ffbuild_configure() {
    echo --enable-libx265
}

ffbuild_unconfigure() {
    echo --disable-libx265
}

ffbuild_cflags() {
    return 0
}

ffbuild_ldflags() {
    return 0
}
