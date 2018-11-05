#!/bin/bash

GIT_BRANCH=${GIT_BRANCH:-master}
CENTOS_VERSION=${CENTOS_VERSION:-7}
CENTOS_ARCH=${CENTOS_ARCH:-x86_64}

REPO_DIR=gluster-prometheus/nightly
REPO_NAME='gluster-prometheus-master'
REPO_VERSION='master'
RSYNC_DIR=gluster/gluster-prometheus-nightly


artifact()
{
    [ -e ~/rsync.passwd ] || return 0
    rsync -av --password-file ~/rsync.passwd "${@}" gluster@artifacts.ci.centos.org::${RSYNC_DIR}/
}

set -e

RESULT_DIR=/srv/${REPO_DIR}/${GIT_BRANCH}/${CENTOS_VERSION}/${CENTOS_ARCH}
mkdir -p "${RESULT_DIR}"

GPGIT=https://github.com/gluster/gluster-prometheus
GPCLONE=${PWD}/gluster-prometheus

yum -y install git createrepo_c

git clone "${GPGIT}" "${GPCLONE}"
pushd "${GPCLONE}"
git checkout "${GIT_BRANCH}"
popd

RESULTDIR=${RESULT_DIR} "${GPCLONE}/extras/nightly-rpms.sh"

pushd "$RESULT_DIR"
createrepo_c .
popd

cat > "/srv/${REPO_DIR}/${REPO_NAME}.repo" <<< "[gluster-prometheus-nightly-${REPO_VERSION}]
name=Gluster Prometheus Exporter Nightly builds (${GIT_BRANCH} branch)
baseurl=http://artifacts.ci.centos.org/${RSYNC_DIR}/${GIT_BRANCH}/\$releasever/\$basearch
enabled=1
gpgcheck=0"

pushd "/srv/${REPO_DIR}"
artifact "${REPO_NAME}.repo"
artifact "${GIT_BRANCH}"
popd

exit
