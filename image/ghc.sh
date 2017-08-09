#!/bin/sh -eu

export DEBIAN_FRONTEND=noninteractive

# install prerequisites

dependencies="
  ca-certificates
  curl
  dnsutils
  gcc
  libffi-dev
  libgmp-dev
  zlib1g-dev
  "
#https://github.com/haskell/cabal/issues/4102

#zlib1g-dev is needed for zlib, used by cabal-install

build_dependencies="
  ghc
  make
  ncurses-dev
  xz-utils
  "

apt-get update
apt-get install -y --no-install-recommends $dependencies $build_dependencies

#switch on gold linker
#https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=718814#15
update-alternatives --install /usr/bin/ld ld /usr/bin/ld.gold 20

#download ghc
echo "silent
show-error" >>~/.curlrc
echo "Downloading GHC ..."
curl https://downloads.haskell.org/~ghc/8.2.1/ghc-8.2.1-src.tar.xz | tar xJ
cd ghc-*

#hpc, hp2ps, runghc and iserv not needed
sed -i '/BUILD_DIRS += utils\/\(hpc\|runghc\|hp2ps\)/d; /BUILD_DIRS += iserv/d' ghc.mk
#skip ghci libraries
sed -i '/"$$(ghc-cabal_INPLACE)" configure/s/$/ --disable-library-for-ghci/' rules/build-package-data.mk

#build
./configure --with-system-libffi
mv /tmp/build.mk mk

make -j$(nproc)
make install-strip

#remove ghc-bundled Cabal, will install latest with cabal-install
ghc-pkg unregister Cabal

#clean up
apt-get purge --auto-remove -y $build_dependencies
/opt/post-apt
rm -r /ghc-* \
      /usr/local/lib/ghc-*/Cabal-* \
      /usr/local/share/doc/ghc-*/html/libraries/Cabal-*

#https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=783876
#https://ghc.haskell.org/trac/ghc/ticket/1851
echo "Stripping ..."
strip --strip-unneeded /usr/lib/x86_64-linux-gnu/*.a \
                       /usr/lib/gcc/x86_64-linux-gnu/6/*.a \
                       /usr/lib/gcc/x86_64-linux-gnu/6/cc1 \
                       /usr/lib/gcc/x86_64-linux-gnu/6/lto1 \
                       /usr/local/lib/ghc-*/rts/*