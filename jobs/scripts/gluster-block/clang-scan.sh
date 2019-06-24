#!/bin/bash

set -e

yum install -y git autoconf automake gcc libtool make file glusterfs-api-devel libuuid-devel json-c-devel libtirpc-devel glibc-common python-setuptools clang clang-analyzer

# get epel and install lcov
yum install -y epel-release centos-release-gluster
yum install -y glusterfs-server

# source code install other centos dependencies
git clone https://github.com/open-iscsi/targetcli-fb
cd targetcli-fb/
./setup.py install
cd ..

git clone https://github.com/open-iscsi/rtslib-fb
cd rtslib-fb
./setup.py install
cp systemd/target.service /usr/lib/systemd/system/target.service
cd ..

git clone https://github.com/open-iscsi/configshell-fb
cd configshell-fb
./setup.py install
cd ..

git clone https://github.com/open-iscsi/tcmu-runner
cd tcmu-runner
yum install -y cmake make gcc libnl3 glib2 zlib kmod libnl3-devel glib2-devel zlib-devel kmod-devel
cmake -DSUPPORT_SYSTEMD=ON -DCMAKE_INSTALL_PREFIX=/usr -Dwith-rbd=false -Dwith-qcow=false -Dwith-zbc=false -Dwith-fbo=false
make install

# get the gluster-block source code
rm -rf gluster-block/
git clone --depth 2 https://github.com/gluster/gluster-block/
pushd gluster-block

scan-build -V -disable-checker deadcode.DeadStores -v -v --use-cc clang --use-analyzer=/usr/bin/clang make
