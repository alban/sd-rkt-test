#!/bin/bash

set -e

export CC=gcc-5

if [ "$1" = "setup" ] ; then
  sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
  sudo add-apt-repository ppa:pitti/systemd-semaphore -y
  sudo rm -rf /etc/apt/sources.list.d/beineri* /home/runner/{.npm,.phpbrew,.phpunit,.kerl,.kiex,.lein,.nvm,.npm,.phpbrew,.rbenv}
  sudo apt-get update -qq

  sudo apt-get install gcc-5 gcc-5-base libgcc-5-dev -y -qq

  sudo apt-get build-dep systemd -y -qq
  sudo apt-get install --force-yes -y -qq util-linux libmount-dev libblkid-dev liblzma-dev libqrencode-dev libmicrohttpd-dev iptables-dev liblz4-dev python-lxml libcurl4-gnutls-dev unifont clang-3.6 libasan0 itstool kbd cryptsetup-bin net-tools isc-dhcp-client iputils-ping strace qemu-system-x86 linux-image-virtual mount
  sudo sh -c 'echo 01010101010101010101010101010101 >/etc/machine-id'
  sudo mount -t tmpfs none /tmp
  test -d /run/mount || sudo mkdir /run/mount
  sudo rm -f /etc/mtab
  sudo groupadd rkt
  sudo gpasswd -a runner rkt
  exit 0
fi

cd
git clone https://github.com/systemd/systemd.git
cd systemd

SYSTEMD_DIR=$PWD
SYSTEMD_BRANCH=master

date
echo "Semaphore thread: $SEMAPHORE_CURRENT_THREAD"
echo "systemd git branch: $SYSTEMD_BRANCH"
echo "systemd git describe: $(git describe HEAD)"
echo "Last two systemd commits:"
git log -n 2 | cat
echo

cd

if [ "$SEMAPHORE_CURRENT_THREAD" = "1" ] ; then
  URL=https://github.com/coreos/rkt.git
  BRANCH=master
elif [ "$SEMAPHORE_CURRENT_THREAD" = "2" ] ; then
  URL=https://github.com/kinvolk/rkt.git
  BRANCH=alban/machine-id
else
  echo "SEMAPHORE_CURRENT_THREAD=$SEMAPHORE_CURRENT_THREAD"
  exit 1
fi

git clone --quiet $URL rkt-with-systemd
cd rkt-with-systemd
git checkout $BRANCH

echo "rkt git branch: $BRANCH"
echo "rkt git describe: $(git describe HEAD)"
echo "Last two rkt commits:"
git log -n 2 | cat
echo

./tests/install-deps.sh

# Set up go environment on semaphore
if [ -f /opt/change-go-version.sh ]; then
    . /opt/change-go-version.sh
    change-go-version 1.5
fi

mkdir -p builds
cd builds
git clone ../ build
pushd build
./autogen.sh
./configure --enable-functional-tests \
      --with-stage1-flavors=src \
      --with-stage1-systemd-src=$SYSTEMD_DIR \
      --with-stage1-systemd-version=$SYSTEMD_BRANCH \
      --enable-tpm=no

make -j 4
make check
popd
sudo rm -rf build

cd ..
rm -rf rkt-with-systemd
