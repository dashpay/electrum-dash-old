#!/bin/bash -l
##
## Functions are being moved to their own scripts in helpers/*.sh
## to allow for easier building by single steps, or for single systems

set -xeo pipefail


sign_release () {
         sha1sum ${release} > ${1}.sha1
         md5sum ${release} > ${1}.md5
         gpg --sign --armor --detach  ${1}
         gpg --sign --armor --detach  ${1}.md5
         gpg --sign --armor --detach  ${1}.sha1
}

build_win32trezor() {
 ./helpers/build-hidapi.sh
}
get_archpkg (){
  if [ "${TYPE}" = "SIGNED" ]
  then 
     archbranch="v${VERSION}"
  else
     archbranch="\"check_repo_for_correct_branch\""
  fi
  test -d ../../contrib/ArchLinux || mkdir -v ../../contrib/ArchLinux
  pushd ../../contrib/ArchLinux
  wget https://aur.archlinux.org/packages/en/electrum-dash-git/electrum-dash-git.tar.gz
  tar -xpzvf electrum-dash-git.tar.gz
  sed -e 's/_gitbranch\=.*/_gitbranch='${archbranch}'/g' electrum-dash-git/PKGBUILD > electrum-dash-git/PKGBUILD.new
  mv electrum-dash-git/PKGBUILD.new electrum-dash-git/PKGBUILD
  rm electrum-dash-git.tar.gz
  popd
}
#build_osx (){
#}
prepare_repo(){
  ./helpers/prepare_repo.sh
}
buildRelease(){
  test -d releases || mkdir -pv $(pwd)/releases
  # echo "Making locales" 
  # $DOCKERBIN run --rm -it --privileged -e MKPKG_VER=${VERSION} -v $(pwd)/helpers:/root  -v $(pwd)/repo:/root/repo  -v $(pwd)/source:/opt/wine-electrum/drive_c/electrum-dash/ -v $(pwd):/root/electrum-dash-release mazaclub/electrum-dash-release:${VERSION} /bin/bash
  echo "Making Release packages for $VERSION"
  test -f helpers/build_release.complete || ./helpers/build_release.sh
}
build_Windows(){
   echo "Making Windows EXEs for $VERSION" \
   && cp build-config.sh helpers/build-config.sh \
   && ./helpers/build_windows.sh 
   #&& $DOCKERBIN run --rm -it --privileged -e MKPKG_VER=${VERSION} -v $(pwd)/helpers:/root  -v $(pwd)/repo:/root/repo  -v $(pwd)/source:/opt/wine-electrum/drive_c/electrum-dash/ -v $(pwd):/root/electrum-dash-release mazaclub/electrumdash-winbuild:${VERSION} /root/build-binary $VERSION \
}
build_OSX(){
   echo "Attempting OSX Build: Requires Darwin Buildhost" 
  if [ "$(uname)" = "Darwin" ];
   then
   if [ ! -f /opt/local/bin/python2.7 ]
   then 
    echo "This build requires macports python2.7 and pyqt4"
    exit 5
   fi
  ./helpers/build_osx.sh ${VERSION} 
  mv helpers/release-packages/OSX helpers/release-packages/OSX-py2app
  ./helpers/build_osx-pyinstaller.sh  ${VERSION} $TYPE
 else
  echo "OSX Build Requires OSX build host!"
 fi \
   && echo "OSX build complete" 
}
build_Linux(){
   echo "Linux Packaging" \
   #&& $DOCKERBIN run --rm -it --privileged -e MKPKG_VER=${VERSION} -v $(pwd)/helpers:/root  -v $(pwd)/repo:/root/repo  -v $(pwd)/source:/opt/wine-electrum/drive_c/electrum-dash/ -v $(pwd):/root/electrum-dash-release mazaclub/electrumdash-release:${VERSION} /root/make_linux ${VERSION}
   ./helpers/build_linux.sh
}
completeReleasePackage(){
#  mv $(pwd)/helpers/release-packages/* $(pwd)/releases/
  if [ "${TYPE}" = "rc" ]; then export TYPE=SIGNED ; fi
  if [ "${TYPE}" = "SIGNED" ] ; then
    ${DOCKERBIN} push mazaclub/electrumdash-winbuild:${VERSION}
    ${DOCKERBIN} push mazaclub/electrumdash-release:${VERSION}
    ${DOCKERBIN} push mazaclub/electrumdash32-release:${VERSION}
    ${DOCKERBIN} tag -f ogrisel/python-winbuilder mazaclub/python-winbuilder:${VERSION}
    ${DOCKERBIN} push mazaclub/python-winbuilder:${VERSION}
    cd releases
    for release in * 
    do
      if [ ! -d ${release} ]; then
         sign_release ${release}
      else
         cd ${release}
         for i in * 
         do 
           if [ ! -d ${i} ]; then
              sign_release ${i}
	   fi
         done
         cd ..
      fi
    done
  fi
  echo "You can find your Electrum-DASHs $VERSION binaries in the releases folder."
  
}

buildImage(){
  echo "Building image"
  case "${1}" in 
  winbuild) $DOCKERBIN build -t mazaclub/electrumdash-winbuild:${VERSION} .
         ;;
   release) $DOCKERBIN build -f Dockerfile-release -t  mazaclub/electrumdash-release:${VERSION} .
         ;;
  esac
}


buildLtcScrypt() {
## this will be integrated into the main build in a later release
   wget https://pypi.python.org/packages/source/l/ltc_scrypt/ltc_scrypt-1.0.tar.gz
   tar -xpzvf ltc_scrypt-1.0.tar.gz
   docker run -ti --rm \
    -e WINEPREFIX="/wine/wine-py2.7.8-32" \
    -v $(pwd)/ltc_scrypt-1.0:/code \
    -v $(pwd)/helpers:/helpers \
    ogrisel/python-winbuilder wineconsole --backend=curses  Z:\\helpers\\ltc_scrypt-build.bat
   cp -av ltc_scrypt-1.0/build/lib.win32-2.7/ltc_scrypt.pyd helpers/ltc_scrypt.pyd

}
buildDarkcoinHash() {
  ./helpers/build_darkcoin-hash.sh
}

prepareFile(){
  echo "Preparing file for Electrum-DASH version $VERSION"
  if [ -e "$TARGETPATH" ]; then
    echo "Version tar already downloaded."
  else
   wget https://github.com/mazaclub/electrum-dash/archive/v${VERSION}.zip -O $TARGETPATH
  fi

  if [ -d "$TARGETFOLDER" ]; then
    echo "Version is already extracted"
  else
     unzip -d $(pwd)/source ${TARGETPATH} 
  fi
}

config (){
# setup build-config.sh for export/import of common variables
#if [[ $# -gt 0 ]]; then
#  echo "#!/bin/bash" > build-config.sh
#  VERSION=$1
#  echo "export VERSION=$1" >> build-config.sh
#  TYPE=${2:-tagged}
#  echo "export TYPE=${2:-tagged}" >> build-config.sh
#  FILENAME=Electrum-DASH-$VERSION.zip
#  echo "export FILENAME=Electrum-DASH-$VERSION.zip" >> build-config.sh
#  TARGETPATH=$(pwd)/source/$FILENAME
#  echo "export TARGETPATH=$(pwd)/source/$FILENAME" >> build-config.sh
#  TARGETFOLDER=$(pwd)/source/Electrum-DASH-$VERSION
#  echo "export TARGETFOLDER=$(pwd)/source/Electrum-DASH-$VERSION" >> build-config.sh
#  echo "Building Electrum-DASH $VERSION from $FILENAME"
#else
#  echo "Usage: ./build <version>."
#  echo "For example: ./build 1.9.8"
#  exit
#fi

# ensure docker is installed
#source helpers/build-common.sh
#if [[ -z "$DOCKERBIN" ]]; then
#        echo "Could not find docker binary, exiting"
#        exit
#else
#        echo "Using docker at $DOCKERBIN"
#fi

# make sure production builds are clean
#if [ "${TYPE}" = "rc" -o "${TYPE}" = "SIGNED" ]
#then 
#   ./clean.sh all
#fi

 ./helpers/config.sh ${VERSION} ${TYPE} ${OS} 
 cat build-config.sh
}



prep_deps () {
## clone python-trezor so we have it for deps, and to include trezorctl.py 
## for pyinstaller to analyze
#test -d python-trezor || git clone https://github.com/mazaclub/python-trezor
## prepare repo for local build
#test -f prepared || prepare_repo
##get_archpkg
#
## build windows C extensions
#test -f helpers/hid.pyd || build_win32trezor
#test -f helpers/darkcoin_hash.pyd || buildDarkcoinHash
#
## Build docker images
#$DOCKERBIN images|awk '{print $1":"$2}'|grep "mazaclub/electrumdash-winbuild:${VERSION}" || buildImage winbuild
#$DOCKERBIN images|awk '{print $1":"$2}'|grep "mazaclub/electrumdash-release:${VERSION}" || buildImage release
## touch FORCE_IMG_BUILD if you want to 
#test -f FORCE_IMG_BUILD &&  buildImage winbuild
#test -f FORCE_IMG_BUILD &&  buildImage release
 test -f prepped || ./helpers/prep_deps.sh
}
pick_build () {
 case "$OS" in
  buildWindows) echo "Windows-Only Build"
 	        build_Windows \ 
                 && mv $(pwd)/helpers/release-packages/Windows $(pwd)/releases/Windows
 	       ;;
    buildLinux) echo "Linux-Only Build"
                build_Linux \
                 && mv $(pwd)/helpers/release-packages/Linux $(pwd)/releases/Linux
 	       ;;
      buildOSX) echo "OSX-Only Build"
                build_OSX \
                 && mv $(pwd)/helpers/release-packages/Linux $(pwd)/releases/Linux
 	       ;;
      build.sh) echo "Building Windows, Linux, and OSX"
                build_Windows \
                 && ls -la $(pwd)/helpers/release-packages/Windows/Electrum-DASH-${VERSION}-Windows-setup.exe \
                 && build_Linux \
                 && build_OSX  \
                 && mv $(pwd)/helpers/release-packages/Linux $(pwd)/releases/Linux
                ;;
 esac
}

# Main script
OS=$(echo $0|awk -F "/" '{print $2}')
VERSION="$1"
TYPE="$2"

echo "RUNNING CONFIG ${VERSION} ${TYPE} ${OS}"

config ${VERSION} ${TYPE} ${OS} \
 && prep_deps \
 && buildRelease \
 && pick_build
# Build release, binaries, and packages
if [[ $? = 0 ]]; then
    echo "Build successful."
else
  echo "Seems like the build failed. Exiting."
  exit
fi

# move completed builds from helpers/release-packages to releases/
# sum and sign the binaries, zipfiles, and tarballs
completeReleasePackage ${OS}
echo "End."
