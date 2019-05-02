#!/bin/bash
set -Ceu
shopt -s globstar

########################################################################
# AppImage generator script for Ubuntu Trusty 16.04
# maintained by Yuto Tokunaga <yuntan.sub1@gmail.com>
# For more information, see http://appimage.org/
########################################################################

sudo apt update
sudo apt install -y git
sudo apt install -y libssl-dev libreadline6-dev libgdbm3 libgdbm-dev # for ruby
sudo apt install -y zlib1g-dev # for `gem install`
sudo apt install -y libidn11-dev # for idn-ruby

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

echo "--> get ruby source"
wget -q https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.6.tar.gz
tar xf ruby-2.3.6.tar.gz

pushd ruby-2.3.6
echo "--> patching Ruby"
# patching Ruby not to use SSLv3_method
# this fix is for systems which disable SSLv3 support e.g. Arch Linux
# see https://github.com/rbenv/ruby-build/wiki#openssl-sslv3_method-undeclared-error
patch -u -p0 < ../no-sslv3-patch.diff

echo "--> compile Ruby and install it into AppDir"
# use relative load paths at run time
./configure --enable-load-relative --prefix=/usr --disable-install-doc
make -j2
make "DESTDIR=$APPDIR" install
# copy license related files
cp -v BSDL COPYING* GPL LEGAL README* $APPDIR/usr/lib/ruby
popd

echo "--> install gems"
pushd "$REPO"
# for Travis CI, disable RVM
GEM_DIR=$APPDIR/usr/lib/ruby/gems/2.3.0
GEM_HOME=$GEM_DIR GEM_PATH=$GEM_DIR $APPDIR/usr/bin/ruby $APPDIR/usr/bin/gem install bundler
# do not install test group
# NOTE option `--without=test` is persistent by .bundle/config
GEM_HOME=$GEM_DIR GEM_PATH=$GEM_DIR $APPDIR/usr/bin/ruby $APPDIR/usr/bin/bundle install --without=test
popd

echo "--> remove unused files"
rm -vrf $APPDIR/usr/share $APPDIR/usr/include $APPDIR/usr/lib/{pkgconfig,debug}
rm -v $APPDIR/**/*.{a,o}
rm -vrf $GEM_DIR/cache

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

./linuxdeploy-x86_64.AppImage \
  --appdir $APPDIR \
  --icon-file mikutter.png \
  --desktop-file mikutter.desktop \
  --custom-apprun AppRun \
  --output appimage

echo "--> generated $OUTPUT"
mv $OUTPUT /vagrant

echo '==> finished'
