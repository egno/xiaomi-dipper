#!/bin/bash
set -xe

ADAPTATION_TOOLS_REPO="https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git"
ADAPTATION_TOOLS_BRANCH="${ADAPTATION_TOOLS_BRANCH:-main}"

apply_build_toolchain_fixes() {
    local repo="$1"
    local setup="$repo/setup_repositories.sh"
    local kernel="$repo/build-kernel.sh"

    if [ -f "$setup" ] && ! grep -q 'chmod +x "$GCC_ARM32_PATH/arm-linux-androideabi/bin/as"' "$setup"; then
        sed -i.bak '/sed -i.bak "1 s:\.\*:#!\/usr\/bin\/env python3:" "$GCC_ARM32_PATH\/arm-linux-androideabi\/bin\/as"/a\            chmod +x "$GCC_ARM32_PATH/arm-linux-androideabi/bin/as"' "$setup"
    fi

    if [ -f "$kernel" ] && ! grep -q 'ARM32_MAKE_ARGS' "$kernel"; then
        sed -i.bak '/export CROSS_COMPILE_ARM32/a\
    ARM32_GCC_BIN="${TMPDOWN}/arm-linux-androideabi-4.9/arm-linux-androideabi/bin"\
    if [ -d "$ARM32_GCC_BIN" ]; then\
        ARM32_MAKE_ARGS=(CC_ARM32="${CROSS_COMPILE_ARM32}gcc -B ${ARM32_GCC_BIN}/")\
    fi' "$kernel"
        sed -i.bak 's/make O="$OUT" $MAKEOPTS /make O="$OUT" $MAKEOPTS "${ARM32_MAKE_ARGS[@]}" /g' "$kernel"
    fi
}

if [ ! -f build/build.sh ]; then
    git clone -b "$ADAPTATION_TOOLS_BRANCH" --depth 1 "$ADAPTATION_TOOLS_REPO" build
fi

apply_build_toolchain_fixes build

exec ./build/build.sh "$@"
