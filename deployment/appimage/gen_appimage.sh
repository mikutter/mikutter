#!/bin/bash
set -Ceu
shopt -s globstar

########################################################################
# AppImage generator script for Ubuntu Trusty 16.04
# maintained by Yuto Tokunaga <yuntan.sub1@gmail.com>
# For more information, see http://appimage.org/
########################################################################

echo "--> get mikutter source"
git clone git://toshia.dip.jp/mikutter.git

REPO="$PWD"/mikutter
APPDIR="$PWD"/AppDir

set +u
[[ -n "$REVISION" ]] && git -C "$REPO" checkout "$REVISION"
set -u

set +u
[[ -z "$ARCH" ]] && export ARCH="$(arch)"
set -u
APP=mikutter
VERSION=$(git -C "$REPO" describe --tags)

echo "--> get jemalloc source"
wget -q https://github.com/jemalloc/jemalloc/releases/download/5.2.0/jemalloc-5.2.0.tar.bz2
tar -xf jemalloc-5.2.0.tar.bz2

echo "--> build jemalloc"
pushd jemalloc-5.2.0
./configure --prefix=/usr
make -j2
sudo make install
make "DESTDIR=$APPDIR" install
popd

echo "--> get ruby source"
ruby_version=2.6.3
wget -q https://cache.ruby-lang.org/pub/ruby/2.6/ruby-$ruby_version.tar.gz
tar xf ruby-$ruby_version.tar.gz

echo "--> compile Ruby and install it into AppDir"
pushd ruby-$ruby_version
# use relative load paths at run time
./configure --enable-load-relative --with-jemalloc --prefix=/usr --disable-install-doc
make -j2
make "DESTDIR=$APPDIR" install
# copy license related files
cp -v BSDL COPYING* GPL LEGAL README* $APPDIR/usr/lib/ruby
popd

echo "--> install gems"
pushd "$REPO"
# for Travis CI, disable RVM
gems=$APPDIR/usr/lib/ruby/gems/2.6.0
# do not install test group
# NOTE option `--without=test` is persistent by .bundle/config
GEM_HOME=$gems GEM_PATH=$gems $APPDIR/usr/bin/ruby $APPDIR/usr/bin/bundle install --without=test
popd

echo "--> remove unused files"
rm -vrf $APPDIR/usr/share $APPDIR/usr/include $APPDIR/usr/lib/{pkgconfig,debug}
rm -v $APPDIR/**/*.{a,o}
rm -vrf $gems/cache

echo "--> copy mikutter"
mkdir -p $APPDIR/usr/share/mikutter
cp -av "$REPO"/{.bundle,core,mikutter.rb,Gemfile,LICENSE,README} $APPDIR/usr/share/mikutter

echo "--> get exec.so"
# use darealshinji/AppImageKit-checkrt's exec.so to exec xdg-open placed
# outside of the AppImage
# see https://github.com/darealshinji/AppImageKit-checkrt/pull/11
mkdir -p $APPDIR/usr/optional || true
wget -q -O $APPDIR/usr/optional/exec.so https://github.com/darealshinji/AppImageKit-checkrt/releases/download/continuous/exec-x86_64.so

echo "--> copy Typelibs for gobject-introspection gem"
cp -av /usr/lib/girepository-* $APPDIR/usr/lib

# echo "--> patch away absolute paths"
# for gobject-introspection gem
# find usr/lib -name libgirepository-1.0.so.1 -exec sed -i -e 's|/usr/lib/girepository-1.0|.////lib/girepository-1.0|g' {} \;

# remove libssl and libcrypto
# see https://github.com/AppImage/AppImageKit/wiki/Desktop-Linux-Platform-Issues#openssl
# blacklist="libssl.so.1 libssl.so.1.0.0 libcrypto.so.1 libcrypto.so.1.0.0"
# blacklist=
# remove libharfbuzz and it's dependencies,
# see https://github.com/AppImage/AppImageKit/issues/454
# blacklist=$blacklist" libharfbuzz.so.0 libfreetype.so.6"
# for f in $blacklist; do
#   found="$(find . -name "$f" -not -path "./usr/optional/*")"
#   for f2 in $found; do
#     rm -vf "$f2" "$(readlink -f "$f2")"
#   done
# done

# prepare files for linuxdeploy
cp "$REPO"/core/skin/data/icon.png mikutter.png
chmod +x AppRun

echo "--> get linuxdeploy"
wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
chmod +x linuxdeploy-x86_64.AppImage

export OUTPUT=$APP-$VERSION-$ARCH.AppImage

linuxdeploy=./linuxdeploy-x86_64.AppImage
./linuxdeploy-x86_64.AppImage --appimage-extract
linuxdeploy=./squashfs-root/AppRun

eval $linuxdeploy \
  --appdir $APPDIR \
  --icon-file mikutter.png \
  --desktop-file mikutter.desktop \
  --custom-apprun AppRun \
  --output appimage

echo "--> generated $OUTPUT"
mv $OUTPUT $VOLUME

echo '==> finished'
