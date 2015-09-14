#!/bin/bash
set -xeo pipefail
source build-config.sh
source helpers/build-common.sh
do_windows (){
 test -f helpers/hid.pyd || build_win32trezor
 test -f helpers/darkcoin_hash.pyd || buildDarkcoinHash
}

# clone python-trezor so we have it for deps, and to include trezorctl.py 
# for pyinstaller to analyze
test -d python-trezor || git clone https://github.com/mazaclub/python-trezor
# prepare repo for local build
test -f prepared || ./helpers/prepare_repo.sh
#get_archpkg

# build windows C extensions
#if [ "$OS" = "buildWindows" ] ; then
# do_windows
#elif [ "${OS}" = "build.sh" ] ; then 
# do_windows
#fi
do_windows

# Build docker images
$DOCKERBIN images|awk '{print $1":"$2}'|grep "mazaclub/electrumdash-winbuild:${VERSION}" || buildImage winbuild
$DOCKERBIN images|awk '{print $1":"$2}'|grep "mazaclub/electrumdash-release:${VERSION}" || buildImage release
# touch FORCE_IMG_BUILD if you want to 
test -f FORCE_IMG_BUILD &&  buildImage winbuild
test -f FORCE_IMG_BUILD &&  buildImage release
touch prepped
echo "prepared"
