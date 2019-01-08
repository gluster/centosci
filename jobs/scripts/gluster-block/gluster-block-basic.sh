#!/bin/bash -e

GIT_BRANCH=${GIT_BRANCH:-master}
CENTOS_VERSION=${CENTOS_VERSION:-7}
CENTOS_ARCH=${CENTOS_ARCH:-x86_64}

REPO_DIR=gluster-block/nightly
REPO_NAME='gluster-block'
REPO_VERSION='master'
RSYNC_DIR=gluster/gluster-block-nightly

artifact()
{
    [ -e ~/rsync.passwd ] || return 0
    rsync -av --password-file ~/rsync.passwd "${@}" gluster@artifacts.ci.centos.org::${RSYNC_DIR}/
}


### Now build The rpms.
# install basic dependencies for building the tarball and srpm
install_dependency()
{
    yum -y install git autoconf automake gcc libtool bison flex
    yum -y install make cmake rpm-build createrepo_c
    # gluster repositories contain additional -devel packages
    yum -y install centos-release-gluster
    yum -y install libuuid-devel targetcli glusterfs-api-devel
    yum -y install libnl3-devel glib2-devel zlib-devel kmod-devel
    yum -y install json-c-devel help2man rpcbind
}

clone_and_build_rpms()
{
    # TCMU-RUNNER
    rm -rf tcmu-runner/
    git clone https://github.com/open-iscsi/tcmu-runner

    pushd tcmu-runner
    cd extra/
    bash make_runnerrpms.sh --without rbd --without qcow --without zbc --without fbo

    # install tcmu runner RPMs so gluster-block dependency can be satisfied
    # notice that tcmu-runner now depends on libtcmu too, which gets built
    # separately
    rpm -i rpmbuild/RPMS/x86_64/*.rpm
    popd

    rm -rf gluster-block/
    git clone --depth 2 https://github.com/gluster/gluster-block/

    pushd gluster-block
    ./autogen.sh
    ./configure
    make rpms
    popd
}

push_rpms_to_repo()
{
    TARGET_DIR="/srv/$REPO_DIR"
    RPMDIR="$TARGET_DIR/master/${CENTOS_VERSION}/${CENTOS_ARCH}"
    mkdir -p ${RPMDIR}

    cp -a tcmu-runner/extra/rpmbuild/RPMS/x86_64/* ${RPMDIR}
    cp -a gluster-block/build/rpmbuild/RPMS/x86_64/* ${RPMDIR}

    pushd "${RPMDIR}"
    createrepo_c .
    popd

    cat > "${TARGET_DIR}/${REPO_NAME}.repo" <<< "[gluster-block-nightly-${REPO_VERSION}]
name=Gluster Block Nightly builds (master branch)
baseurl=http://artifacts.ci.centos.org/${RSYNC_DIR}/master/\$releasever/\$basearch
enabled=1
gpgcheck=0"

    pushd "$TARGET_DIR"
    artifact "${REPO_NAME}.repo"
    artifact "master"
    popd
}

main()
{
    install_dependency
    clone_and_build_rpms

    # Copy RPMS
    # Sync it to relevant server

    push_rpms_to_repo
}

main "$@"
