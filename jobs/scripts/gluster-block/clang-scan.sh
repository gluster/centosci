#!/bin/bash
MOCK="sudo mock -r $MOCK_CHROOT --config-opts=dnf_warning=False"

$MOCK --init
# get epel and install packages
$MOCK --install epel-release
$MOCK --install git cmake libnl3 glib2 zlib kmod libnl3-devel glib2-devel zlib-devel kmod-devel autoconf automake gcc libtool make file glusterfs-api-devel libuuid-devel json-c-devel libtirpc-devel glibc-common python-setuptools clang clang-analyzer

# source code install other centos dependencies
$MOCK --chroot "git clone https://github.com/open-iscsi/targetcli-fb && ./targetcli-fb/setup.py install"

$MOCK --chroot "git clone https://github.com/open-iscsi/rtslib-fb && ./rtslib-fb/setup.py install && cp ./rtslib-fb/systemd/target.service /usr/lib/systemd/system/target.service"

$MOCK --chroot "git clone https://github.com/open-iscsi/configshell-fb && ./configshell-fb/setup.py install"

$MOCK --chroot "git clone https://github.com/open-iscsi/tcmu-runner && cd tcmu-runner && cmake -DSUPPORT_SYSTEMD=ON -DCMAKE_INSTALL_PREFIX=/usr -Dwith-rbd=false -Dwith-qcow=false -Dwith-zbc=false -Dwith-fbo=false && make install && cd .."

$MOCK --chroot "git clone --depth 2 https://github.com/gluster/gluster-block/ && ./gluster-block/autogen.sh && ./gluster-block/configure CC=clang --enable-gnfs --enable-debug"

$MOCK --chroot "scan-build -o clangScanBuildReports -disable-checker deadcode.DeadStores -v -v --use-cc clang --use-analyzer=/usr/bin/clang make"

$MOCK --clean
