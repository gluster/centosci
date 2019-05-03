#!/bin/bash

set -e

yum install -y git autoconf automake gcc libtool make file glusterfs-api-devel libuuid-devel json-c-devel libtirpc-devel glibc-common

# install runtime dependencies
yum install -y glusterfs-server targetcli tcmu-runner

# install lcov
http://download-ib01.fedoraproject.org/pub/epel/7/x86_64/
rpm -Uvh epel-release*rpm
yum install lcov

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
