#!/bin/sh

# Builds the SnesRev Launcher AppImage: the Zelda 3, Super Metroid and Super
# Mario World PC ports behind one launcher, with the ROM patching and asset
# extraction tools they need.
#
# The ports are compiled from source and the launcher is a POSIX shell script,
# which is why this one has more build steps than most. No ROM is ever
# downloaded or shipped: the user brings their own dumps.

set -eu

SCRIPT_DIR=$(cd "${0%/*}" && pwd)
ARCH=$(uname -m)
SHARUN="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/quick-sharun.sh"
EXTRA_PACKAGES="https://raw.githubusercontent.com/${GITHUB_REPOSITORY%/*}/${GITHUB_REPOSITORY#*/}/refs/heads/main/useful-tools/get-debloated-pkgs.sh"

export ARCH
export OUTPATH=./dist
export OUTNAME=SnesRev_Launcher-"$ARCH".AppImage
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=https://raw.githubusercontent.com/TheRealYasri/snesrev-launcher/2364f51d3d3f9bebd3bde416a33f2e0840181345/snesrev.AppDir/snesrev.png
export DESKTOP="$SCRIPT_DIR"/snesrev-launcher/snesrev.desktop
export STARTUPWMCLASS=snesrev

# The launcher drives the ports through python, and flips (behind zenity) is
# what applies the Redux patches.
export DEPLOY_PYTHON=1
export DEPLOY_SDL=1
export DEPLOY_OPENGL=1

# Only the ports need to be traced for dlopened libraries, the launcher itself
# would just open its game picker and sit there.
export STRACE_BINARY="zelda3 sm smw"

# Everything below is pinned, so a rebuild only changes when we say so.
LAUNCHER_URL=https://raw.githubusercontent.com/TheRealYasri/snesrev-launcher/2364f51d3d3f9bebd3bde416a33f2e0840181345/snesrev.AppDir

ZELDA3_REPO=https://github.com/snesrev/zelda3
ZELDA3_COMMIT=45a149d8b4bb8098f53d1009f76e76e7d8b79bbf

SM_REPO=https://github.com/snesrev/sm
SM_COMMIT=578f90b3cc49557bb70060ad033bb90b8cf8ac50

SM_REDUX_REPO=https://github.com/testyourmine/sm-redux
SM_REDUX_COMMIT=2bcb31065ade54cf354eb8989f0dcb9929077f11

SMW_REPO=https://github.com/nightmareci/smw
SMW_COMMIT=41b264ef1491597aafbc66b8ca4bdf2128390d7e

FLIPS_REPO=https://github.com/Alcaro/Flips
FLIPS_COMMIT=ff216a75df0987047a67d7923567dc4482ce07ac

pacman -Syu --noconfirm \
    base-devel       \
    git              \
    gtk3             \
    libxcb           \
    libxcursor       \
    libxi            \
    libxkbcommon     \
    libxkbcommon-x11 \
    libxrandr        \
    libxtst          \
    patchelf         \
    python           \
    python-pillow    \
    python-yaml      \
    python-zstandard \
    sdl2-compat      \
    wget             \
    xorg-server-xvfb \
    zenity

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
wget --retry-connrefused --tries=30 "$EXTRA_PACKAGES" -O ./get-debloated-pkgs.sh
chmod +x ./get-debloated-pkgs.sh
./get-debloated-pkgs.sh --add-common --prefer-nano

echo "Building the ports..."
echo "---------------------------------------------------------------"
git clone "$ZELDA3_REPO" ./src-zelda3
git -C ./src-zelda3 checkout "$ZELDA3_COMMIT"
make -C ./src-zelda3 -j"$(nproc)" zelda3

git clone "$SM_REPO" ./src-sm
git -C ./src-sm checkout "$SM_COMMIT"
make -C ./src-sm -j"$(nproc)" sm

git clone "$SM_REDUX_REPO" ./src-sm-redux
git -C ./src-sm-redux checkout "$SM_REDUX_COMMIT"
make -C ./src-sm-redux -j"$(nproc)" sm

git clone "$SMW_REPO" ./src-smw
git -C ./src-smw checkout "$SMW_COMMIT"
make -C ./src-smw -j"$(nproc)" smw

git clone "$FLIPS_REPO" ./src-flips
git -C ./src-flips checkout "$FLIPS_COMMIT"
TARGET=cli make -C ./src-flips CFLAGS="-O2 -flto"

echo "Assembling the launcher payload..."
echo "---------------------------------------------------------------"
# $APPDIR/share/snesrev holds everything the launcher reads at runtime, and is
# laid out the way the ports' own tools expect to find their files.
mkdir -p ./snesrev/tools/zelda3 ./snesrev/tools/smw ./snesrev/tools/sm
mkdir -p ./snesrev/icons ./snesrev/patches

LAUNCHER=$SCRIPT_DIR/snesrev-launcher/snesrev-launcher

for i in z3 sm smw; do
    wget --retry-connrefused --tries=30 "$LAUNCHER_URL/$i.png" -O ./snesrev/icons/"$i".png
done

# Redux is a romhack of the base games, so the patches let the launcher build
# those ROMs for people who only own the originals.
wget --retry-connrefused --tries=30 "$LAUNCHER_URL/z3.redux.ips" -O ./snesrev/patches/z3.redux.ips
wget --retry-connrefused --tries=30 "$LAUNCHER_URL/sm.redux.ips" -O ./snesrev/patches/sm.redux.ips

# zelda3: restool.py chdirs into assets/, reads the ROM from the directory
# above it and writes zelda3_assets.dat there.
cp -R ./src-zelda3/assets ./snesrev/tools/zelda3/assets
cp -R ./src-zelda3/other ./snesrev/tools/zelda3/other
cp ./src-zelda3/zelda3.ini ./snesrev/tools/zelda3/zelda3.ini

# smw: the asset tools read assets/smw.sfc and write smw_assets.dat in the
# parent directory, and SMB1/The Lost Levels are carved out of All-Stars by
# other/extract.py with the dictionaries next to it.
cp -R ./src-smw/assets ./snesrev/tools/smw/assets
mkdir -p ./snesrev/tools/smw/other
cp ./src-smw/other/extract.py ./snesrev/tools/smw/other/extract.py
cp ./src-smw/other/smb1.zst ./src-smw/other/smbll.zst ./snesrev/tools/smw/other/
cp ./src-smw/smw.ini ./snesrev/tools/smw/smw.ini

cp ./src-sm/sm.ini ./snesrev/tools/sm/sm.ini

# The asset tools never read these
rm -rf ./snesrev/tools/zelda3/other/msu
rm -f ./snesrev/tools/zelda3/other/glitches_faq.txt

echo "Deploying the AppImage..."
echo "---------------------------------------------------------------"
mkdir -p ./AppDir/bin ./AppDir/share
cp "$LAUNCHER" ./AppDir/bin/snesrev-launcher
chmod +x ./AppDir/bin/snesrev-launcher
cp -R ./snesrev ./AppDir/share/snesrev
cp ./src-zelda3/zelda3 ./AppDir/bin/zelda3
cp ./src-sm/sm ./AppDir/bin/sm
cp ./src-sm-redux/sm ./AppDir/bin/sm-redux
cp ./src-smw/smw ./AppDir/bin/smw
cp ./src-flips/flips ./AppDir/bin/flips

wget --retry-connrefused --tries=30 "$SHARUN" -O ./quick-sharun
chmod +x ./quick-sharun

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

./quick-sharun "$@"

./quick-sharun --make-appimage

# The ports need a ROM to start, so only the launcher's own help output can be
# tested here.
./quick-sharun --simple-test ./dist/*.AppImage help
