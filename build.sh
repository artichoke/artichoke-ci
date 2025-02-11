#!/usr/bin/env bash

set -euo pipefail
set -x

echo 'APT::Get::Assume-Yes "true";' >/etc/apt/apt.conf.d/90artichokeci
echo 'DPkg::Options "--force-confnew";' >>/etc/apt/apt.conf.d/90artichokeci

export DEBIAN_FRONTEND=noninteractive

# Make sure PATH includes ~/.local/bin
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=839155
# shellcheck disable=SC2016
echo 'PATH="$HOME/.local/bin:$PATH"' >>/etc/profile.d/user-local-path.sh

# man directory is missing in some base images
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199
apt-get update
mkdir -p /usr/share/man/man1
apt-get install \
  apt \
  bzip2 \
  ca-certificates \
  curl \
  git \
  gnupg \
  gpg \
  gzip \
  jq \
  locales \
  make \
  mercurial \
  netcat \
  net-tools \
  openssh-client \
  parallel \
  software-properties-common \
  sudo \
  tar \
  unzip \
  wget \
  xvfb \
  zip \
  ;

# Set timezone to UTC by default
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
locale-gen C.UTF-8 || true
export LANG=C.UTF-8

###################################
# Start of Ruby Install
# https://github.com/docker-library/ruby/blob/bffb6ff1fbe37874ed506a15eb1bb7faffca589b/2.6/stretch/Dockerfile
###################################

# skip installing gem documentation
mkdir -p /usr/local/etc
{
  echo 'install: --no-document'
  echo 'update: --no-document'
} >>/usr/local/etc/gemrc

export RUBY_MAJOR=2.6
export RUBY_VERSION=2.6.3
export RUBY_DOWNLOAD_SHA256=11a83f85c03d3f0fc9b8a9b6cad1b2674f26c5aaa43ba858d4b0fcc2b54171e1

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
savedAptMark="$(apt-mark showmanual)"
apt-get update
apt-get install -y --no-install-recommends \
  bison \
  dpkg-dev \
  libgdbm-dev \
  ruby \
  ;
rm -rf /var/lib/apt/lists/*

wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz"
echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict

mkdir -p /usr/src/ruby
tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1
rm ruby.tar.xz

pushd /usr/src/ruby
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
{
  echo '#define ENABLE_PATH_CHECK 0'
  echo
  cat file.c
} >file.c.new
mv file.c.new file.c

autoconf
gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
./configure \
  --build="$gnuArch" \
  --disable-install-doc \
  --enable-shared \
  ;

make -j "$(nproc)"
make install

apt-mark auto '.*' >/dev/null
# shellcheck disable=SC2086
apt-mark manual $savedAptMark >/dev/null
find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' |
  awk '/=>/ { print $(NF-1) }' |
  sort -u |
  xargs -r dpkg-query --search || : |
  cut -d: -f1 |
  sort -u |
  xargs -r apt-mark manual \
  ;
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

popd
rm -r /usr/src/ruby
# verify we have no "ruby" packages installed
if dpkg -l | grep -i ruby; then exit 1; fi
[ "$(command -v ruby)" = '/usr/local/bin/ruby' ]
# rough smoke test
ruby --version
gem --version
bundle --version

# install things globally, for great justice
# and don't create ".bundle" in all our apps
export GEM_HOME=/usr/local/bundle
export BUNDLE_PATH="$GEM_HOME"
export BUNDLE_SILENCE_ROOT_WARNING=1
export BUNDLE_APP_CONFIG="$GEM_HOME"
# path recommendation: https://github.com/bundler/bundler/pull/6469#issuecomment-383235438
export PATH="$GEM_HOME/bin:$BUNDLE_PATH/gems/bin:$PATH"
# adjust permissions of a few directories for running "gem install" as an arbitrary user
mkdir -p "$GEM_HOME" && chmod 777 "$GEM_HOME"
# (BUNDLE_PATH = GEM_HOME, no need to mkdir/chown both)

###################################
# End of Ruby Install
###################################

###################################
# Start of Rust Install
# https://github.com/rust-lang/docker-rust/blob/5f31dd180a1c0ba7ce33fc1b983378e0eed336f1/1.36.0/buster/Dockerfile
###################################

export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo
export PATH="/usr/local/cargo/bin:$PATH"
export RUST_VERSION="nightly-2019-07-08"

dpkgArch="$(dpkg --print-architecture)"
case "${dpkgArch##*-}" in
  amd64)
    rustArch='x86_64-unknown-linux-gnu'
    rustupSha256='a46fe67199b7bcbbde2dcbc23ae08db6f29883e260e23899a88b9073effc9076'
    ;;
  armhf)
    rustArch='armv7-unknown-linux-gnueabihf'
    rustupSha256='6af5abbbae02e13a9acae29593ec58116ab0e3eb893fa0381991e8b0934caea1'
    ;;
  arm64)
    rustArch='aarch64-unknown-linux-gnu'
    rustupSha256='51862e576f064d859546cca5f3d32297092a850861e567327422e65b60877a1b'
    ;;
  i386)
    rustArch='i686-unknown-linux-gnu'
    rustupSha256='91456c3e6b2a3067914b3327f07bc182e2a27c44bff473263ba81174884182be'
    ;;
  *)
    echo >&2 "unsupported architecture: ${dpkgArch}"
    exit 1
    ;;
esac
url="https://static.rust-lang.org/rustup/archive/1.18.3/${rustArch}/rustup-init"
wget "$url"
echo "${rustupSha256} *rustup-init" | sha256sum -c -
chmod +x rustup-init
./rustup-init -y --no-modify-path --default-toolchain $RUST_VERSION
rm rustup-init
chmod -R a+w "$RUSTUP_HOME" "$CARGO_HOME"

rustup --version
cargo --version
rustc --version

rustup component add rustfmt
rustup component add clippy

rustfmt --version
cargo clippy -V

rustup target add wasm32-unknown-emscripten
rustup target add wasm32-unknown-unknown

curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

###################################
# End of Rust Install
###################################

###################################
# Start of Node.js Install
# https://github.com/nodejs/docker-node/blob/20c27a952d7cfbd1da8852a77ee72209b81b20a8/12/buster/Dockerfile
###################################

export NODE_VERSION="12.8.1"

ARCH=
dpkgArch="$(dpkg --print-architecture)"
case "${dpkgArch##*-}" in
  amd64) ARCH='x64' ;;
  ppc64el) ARCH='ppc64le' ;;
  s390x) ARCH='s390x' ;;
  arm64) ARCH='arm64' ;;
  armhf) ARCH='armv7l' ;;
  i386) ARCH='x86' ;;
  *)
    echo "unsupported architecture"
    exit 1
    ;;
esac
# gpg keys listed at https://github.com/nodejs/node#release-keys
for key in \
  94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
  FD3A5288F042B6850C66B31F09FE44734EB7990E \
  71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
  DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  B9AE9905FFD7803F25714661B63B535A4C206CA9 \
  77984A986EBC2AA786BC0F66B01FBB92821C587A \
  8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
  4ED778F539E3634C779C87C6D7062848A1AB005C \
  A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
  B9E2F5981AA6E0CD28160D9FF13993A75599653C; do
  gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" ||
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" ||
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" \
    ;
done
curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz"
curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc"
gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc
grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c -
tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner
rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt
ln -s /usr/local/bin/node /usr/local/bin/nodejs

export YARN_VERSION=1.17.3

# shellcheck disable=SC2043
for key in \
  6A010C5166006599AA17F08146C2130DFD2497F5; do
  gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" ||
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" ||
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" \
    ;
done
curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz"
curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc"
gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz
mkdir -p /opt
tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/
ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn
ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg
rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

###################################
# End of Node.js Install
###################################

###################################
# Start of clang Install
###################################

export LLVM_PKG_VERSION=9

apt-key adv --fetch-keys https://apt.llvm.org/llvm-snapshot.gpg.key
apt-add-repository 'deb http://apt.llvm.org/buster/ llvm-toolchain-buster main'
apt-get update
apt-get install "llvm-$LLVM_PKG_VERSION" "clang-$LLVM_PKG_VERSION" "lld-$LLVM_PKG_VERSION"

ln -s "$(command -v "llvm-config-$LLVM_PKG_VERSION")" /usr/local/bin/llvm-config
ln -s "$(command -v "clang-$LLVM_PKG_VERSION")" /usr/local/bin/clang
ln -s "$(command -v "lld-$LLVM_PKG_VERSION")" /usr/local/bin/lld
ln -s "$(command -v "wasm-ld-$LLVM_PKG_VERSION")" /usr/local/bin/wasm-ld
ln -s "$(command -v "llvm-ar-$LLVM_PKG_VERSION")" /usr/local/bin/ar

clang --version

apt-get install bison gperf
apt-get install wabt

export CC=clang

###################################
# End of clang Install
###################################

groupadd --gid 3434 artichoke
useradd --uid 3434 --gid artichoke --shell /bin/bash --create-home artichoke
echo 'artichoke ALL=NOPASSWD: ALL' >>/etc/sudoers.d/50-artichoke
echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >>/etc/sudoers.d/env_keep
