#!/bin/bash

set -e

yum install -y git autoconf automake gcc libtool make file glusterfs-api-devel libuuid-devel json-c-devel libtirpc-devel glibc-common python-setuptools

# get epel and install lcov
yum install -y epel-release centos-release-gluster
yum install -y lcov glusterfs-server

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

nproc=$(getconf _NPROCESSORS_ONLN)

# compile and istall from source code with lcov
pushd gluster-block
./autogen.sh
./configure CFLAGS="-g3 -O0 -lgcov --coverage -fprofile-arcs -ftest-coverage"
make install -j ${nproc}

echo "Initializing the line coverage"
mkdir coverage
lcov -d . --zerocounters
lcov -i -c -d . -o coverage/gluster-block-lcov.info
set +e

# start glusterd process
systemctl start glusterd

# run the test cases
./tests/basic.t
TEST_STATUS=$?

echo "Capturing the line coverage in the .info file"
lcov -c -d . -o coverage/gluster-block-lcov.info
sed -i.bak '/stdout/d' coverage/gluster-block-lcov.info

#Generating the html page for code coverage details using genhtml
genhtml -o coverage/ coverage/gluster-block-lcov.info
echo "The HTML report is generated as index.html file"
popd

if [ $TEST_STATUS -ne 0 ];
    then
    echo "Tests failed"
    exit 1
fi
