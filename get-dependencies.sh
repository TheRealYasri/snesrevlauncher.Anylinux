#!/bin/sh

set -eu

ARCH=$(uname -m)
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export ARCH

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
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
get-debloated-pkgs --add-common --prefer-nano

echo "Building the ports..."
echo "---------------------------------------------------------------"
git clone https://github.com/snesrev/zelda3 ./src-zelda3
git -C ./src-zelda3 checkout 45a149d8b4bb8098f53d1009f76e76e7d8b79bbf
make -C ./src-zelda3 -j"$(nproc)" zelda3

git clone https://github.com/snesrev/sm ./src-sm
git -C ./src-sm checkout 578f90b3cc49557bb70060ad033bb90b8cf8ac50
make -C ./src-sm -j"$(nproc)" sm

git clone https://github.com/testyourmine/sm-redux ./src-sm-redux
git -C ./src-sm-redux checkout 2bcb31065ade54cf354eb8989f0dcb9929077f11
make -C ./src-sm-redux -j"$(nproc)" sm

git clone https://github.com/nightmareci/smw ./src-smw
git -C ./src-smw checkout 41b264ef1491597aafbc66b8ca4bdf2128390d7e
make -C ./src-smw -j"$(nproc)" smw

git clone https://github.com/Alcaro/Flips ./src-flips
git -C ./src-flips checkout ff216a75df0987047a67d7923567dc4482ce07ac
TARGET=cli make -C ./src-flips CFLAGS="-O2 -flto"

echo "Assembling the launcher payload..."
echo "---------------------------------------------------------------"
# Everything the launcher reads at runtime lives under AppDir/share/snesrev,
# laid out the way the ports' own asset tools expect to find their files.
mkdir -p ./AppDir/bin ./AppDir/share/snesrev/tools/zelda3
mkdir -p ./AppDir/share/snesrev/tools/smw/other ./AppDir/share/snesrev/tools/sm
mkdir -p ./AppDir/share/snesrev/icons ./AppDir/share/snesrev/patches

LAUNCHER_DIR="$SCRIPT_DIR/build files"

cp "$LAUNCHER_DIR/snesrev-launcher" ./AppDir/bin/snesrev-launcher
chmod +x ./AppDir/bin/snesrev-launcher

for i in z3 sm smw; do
    wget --retry-connrefused --tries=30 \
        "https://raw.githubusercontent.com/TheRealYasri/snesrev-launcher/2364f51d3d3f9bebd3bde416a33f2e0840181345/snesrev.AppDir/$i.png" \
        -O ./AppDir/share/snesrev/icons/"$i".png
done

# Redux is a romhack of the base games, so these patches let the launcher build
# those ROMs for people who only own the originals.
cp "$LAUNCHER_DIR"/z3.redux.ips ./AppDir/share/snesrev/patches/z3.redux.ips
cp "$LAUNCHER_DIR"/sm.redux.ips ./AppDir/share/snesrev/patches/sm.redux.ips

# zelda3: restool.py chdirs into assets/, reads the ROM from the directory
# above it and writes zelda3_assets.dat there.
cp -R ./src-zelda3/assets ./AppDir/share/snesrev/tools/zelda3/assets
cp -R ./src-zelda3/other ./AppDir/share/snesrev/tools/zelda3/other
cp ./src-zelda3/zelda3.ini ./AppDir/share/snesrev/tools/zelda3/zelda3.ini

# smw: the asset tools read assets/smw.sfc and write smw_assets.dat in the
# parent directory, and SMB1/The Lost Levels are carved out of All-Stars by
# other/extract.py with the dictionaries next to it.
cp -R ./src-smw/assets ./AppDir/share/snesrev/tools/smw/assets
cp ./src-smw/other/extract.py ./AppDir/share/snesrev/tools/smw/other/extract.py
cp ./src-smw/other/smb1.zst ./src-smw/other/smbll.zst ./AppDir/share/snesrev/tools/smw/other/
cp ./src-smw/smw.ini ./AppDir/share/snesrev/tools/smw/smw.ini

cp ./src-sm/sm.ini ./AppDir/share/snesrev/tools/sm/sm.ini

# The asset tools never read these
rm -rf ./AppDir/share/snesrev/tools/zelda3/other/msu
rm -f ./AppDir/share/snesrev/tools/zelda3/other/glitches_faq.txt

cp ./src-zelda3/zelda3 ./AppDir/bin/zelda3
cp ./src-sm/sm ./AppDir/bin/sm
cp ./src-sm-redux/sm ./AppDir/bin/sm-redux
cp ./src-smw/smw ./AppDir/bin/smw
cp ./src-flips/flips ./AppDir/bin/flips

echo "1.10.0" > ~/version
