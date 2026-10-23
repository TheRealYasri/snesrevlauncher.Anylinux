#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export OUTNAME=SnesRev_Launcher-"$ARCH".AppImage
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=https://raw.githubusercontent.com/TheRealYasri/snesrev-launcher/2364f51d3d3f9bebd3bde416a33f2e0840181345/snesrev.AppDir/snesrev.png
export DESKTOP="$PWD"/useful-tools/demo/snesrev-launcher/snesrev.desktop
export STARTUPWMCLASS=snesrev

# The launcher drives the ports through python, and flips applies the Redux
# patches.
export DEPLOY_PYTHON=1
export DEPLOY_SDL=1
export DEPLOY_OPENGL=1

# Only the ports need to be traced for dlopened libraries, the launcher itself
# would just open its game picker and sit there.
export STRACE_BINARY="zelda3 sm smw"

# The asset tools are python scripts that import PyYAML, Pillow and zstandard.
# Their python files come along with the python directory quick-sharun deploys,
# but the C extensions and the libraries those link against have to be passed
# explicitly.
set -- \
    ./AppDir/bin/snesrev-launcher \
    ./AppDir/bin/zelda3          \
    ./AppDir/bin/sm              \
    ./AppDir/bin/sm-redux        \
    ./AppDir/bin/smw             \
    ./AppDir/bin/flips           \
    /usr/bin/zenity

for f in /usr/lib/python*/site-packages/yaml/_yaml*.so \
         /usr/lib/python*/site-packages/PIL/_imaging*.so \
         /usr/lib/python*/site-packages/zstandard/*.so; do
    [ -f "$f" ] || continue
    set -- "$@" "$f"
done

quick-sharun "$@"

quick-sharun --make-appimage

# The ports need a ROM to start, so only the launcher's own help output can be
# tested here.
quick-sharun --simple-test ./dist/*.AppImage help
