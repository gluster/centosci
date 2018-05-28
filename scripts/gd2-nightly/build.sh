#!/bin/bash

GIT_BRANCH=${GIT_BRANCH:-master}
CENTOS_VERSION=${CENTOS_VERSION:-7}
CENTOS_ARCH=${CENTOS_ARCH:-x86_64}

REPO_DIR=glusterd2/nightly
REPO_NAME='gd2-master'
REPO_VERSION='master'


artifact()
{
    [ -e ~/rsync.passwd ] || return 0
    rsync -av --password-file ~/rsync.passwd "${@}" gluster@artifacts.ci.centos.org::${REPO_DIR}/
}

set -e

RESULT_DIR=/srv/${REPO_DIR}/${GIT_BRANCH}/${CENTOS_VERSION}/${CENTOS_ARCH}
mkdir -p "${RESULT_DIR}"

GD2GIT=https://github.com/gluster/glusterd2
GD2CLONE=${PWD}/glusterd2

yum -y install git createrepo_c

git clone "${GD2GIT}" "${GD2CLONE}"
pushd "${GD2CLONE}"
git checkout "${GIT_BRANCH}"
popd

RESULTDIR=${RESULT_DIR} "${GD2CLONE}/extras/nightly-rpms.sh"

pushd "$RESULT_DIR"
createrepo_c .
popd

cat > "/srv/${REPO_DIR}/${REPO_NAME}.repo" <<< "[glusterd2-nightly-${REPO_VERSION}]
name=GD2 Nightly builds (${GIT_BRANCH} branch)
baseurl=http://artifacts.ci.centos.org/${REPO_DIR}/${GIT_BRANCH}/\$releasever/\$basearch
enabled=1
gpgcheck=0"

pushd "/srv/${REPO_DIR}"
artifact "${REPO_NAME}.repo"
artifact "${GIT_BRANCH}"
popd

exit "${RET}"
