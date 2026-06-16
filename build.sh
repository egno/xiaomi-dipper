#!/bin/bash
set -xe

ADAPTATION_TOOLS_REPO="https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git"
ADAPTATION_TOOLS_BRANCH="${ADAPTATION_TOOLS_BRANCH:-main}"

if [ ! -f build/build.sh ]; then
    git clone -b "$ADAPTATION_TOOLS_BRANCH" --depth 1 "$ADAPTATION_TOOLS_REPO" build
fi

exec ./build/build.sh "$@"
