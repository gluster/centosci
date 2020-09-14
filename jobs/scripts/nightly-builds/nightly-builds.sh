#!/bin/bash

artifact()
{
    [ -e ~/rsync.passwd ] || return 0
    rsync -av --password-file ~/rsync.passwd ${@} gluster@artifacts.ci.centos.org::gluster/nightly/
}

# if anything fails, we'll abort
set -e

[ -n "${GERRIT_BRANCH}" ] || ( echo "environment variable GERRIT_BRANCH is required"; exit 1 )
[ -n "${CENTOS_VERSION}" ] || ( echo "environment variable CENTOS_VERSION is required"; exit 1 )
[ -n "${CENTOS_ARCH}" ] || ( echo "environment variable CENTOS_ARCH is required"; exit 1 )

# install basic dependencies for building the tarball and srpm
yum -y install git autoconf automake gcc libtool bison flex make rpm-build mock createrepo_c centos-packager
# gluster repositories contain additional -devel packages
yum -y install centos-release-storage-common centos-release-gluster
yum -y install python-devel libaio-devel librdmacm-devel libattr-devel libxml2-devel readline-devel openssl-devel libibverbs-devel fuse-devel glib2-devel userspace-rcu-devel libacl-devel sqlite-devel libuuid-devel

# clone the repository, github is faster than our Gerrit
#git clone https://review.gluster.org/glusterfs
git clone --depth 1 --branch ${GERRIT_BRANCH} https://github.com/gluster/glusterfs
cd glusterfs/

# generate a version based on branch.last-commit-date.last-commit-hash
if [ ${GERRIT_BRANCH} = 'master' ]; then
    GIT_VERSION=''
    GIT_HASH="$(git log -1 --format=%h)"
    GIT_DATE="$(git log -1 --format=format:%cd --date=short | sed 's/-//g')"
    VERSION="${GIT_DATE}.${GIT_HASH}"
    # there is no cbs-tag storage?-gluster-master-el?-build, use latest tag
    CBS_TAG_VERSION='7'
else
    GIT_VERSION="$(sed 's/.*-//' <<< ${GERRIT_BRANCH})"
    GIT_HASH="$(git log -1 --format=%h)"
    GIT_DATE="$(git log -1 --format=format:%cd --date=short | sed 's/-//g')"
    VERSION="${GIT_VERSION}.${GIT_DATE}.${GIT_HASH}"
    CBS_TAG_VERSION="${GIT_VERSION}"
fi

# Because this is a shallow clone, there are no tags in the git repository. It
# is not possible to use ./build-aux/pkg-version to get a matching version of a
# release. Create a VERSION file so that ./build-aux/pkg-version will not
# return any errors.
echo "v${VERSION}" > VERSION

# unique tag to use in git
TAG="${VERSION}-$(date +%Y%m%d).${GIT_HASH}"

if grep -q -E '^AC_INIT\(.*\)$' configure.ac; then
    # replace the default version by our autobuild one
    sed -i "s/^AC_INIT(.*)$/AC_INIT([glusterfs],[${VERSION}],[gluster-devel@gluster.org])/" configure.ac

    # Add a note to the ChangeLog (generated with 'make dist')
    git commit -q -n --author='Autobuild <gluster-devel@gluster.org>' \
        -m "autobuild: set version to ${VERSION}" configure.ac
fi

# generate the tar.gz archive
./autogen.sh
./configure --enable-fusermount --enable-gnfs
rm -f *.tar.gz
make dist

# build the SRPM
rm -f *.src.rpm
SRPM=$(rpmbuild --define 'dist .autobuild' --define "_srcrpmdir ${PWD}" \
    --define '_source_payload w9.gzdio' \
    --define '_source_filedigest_algorithm 1' \
    -ts glusterfs-${VERSION}.tar.gz | cut -d' ' -f 2)

MOCK_RPM_OPTS=''
case "${CENTOS_VERSION}/${GIT_VERSION}" in
    6/4*|6/5*)
        # CentOS-6 does not support server builds from Gluster 4.0 onwards
	# TODO: once glusterfs-3.x is obsolete, always set this for CentOS-6
        MOCK_RPM_OPTS='--without=server'
        ;;
    *)
        # gnfs is not enabled by default, but our regression tests depend on it
        MOCK_RPM_OPTS='--with=gnfs'
        ;;
esac

# fetch the mock buildroot configuration from the CBS
CBS_TAG="storage${CENTOS_VERSION}-gluster-${CBS_TAG_VERSION}-el${CENTOS_VERSION}-build"
# the MOCK_ROOT should match config_opts['root'] from the mock-config
MOCK_ROOT="${CBS_TAG}-repo_latest"
koji -p cbs mock-config --latest --arch="${CENTOS_ARCH}" --tag="${CBS_TAG}" > /etc/mock/"${MOCK_ROOT}".cfg

# do the actual RPM build in mock
# TODO: use a CentOS Storage SIG buildroot
RESULTDIR=/srv/gluster/nightly/${GERRIT_BRANCH}/${CENTOS_VERSION}/${CENTOS_ARCH}
/usr/bin/mock \
    --root "${MOCK_ROOT}" \
    ${MOCK_RPM_OPTS} \
    --resultdir ${RESULTDIR} \
    --rebuild ${SRPM}

pushd ${RESULTDIR}
createrepo_c .
popd

# create a new .repo file (for new branches, and it prevents cleanup)
if [ -z "${GIT_VERSION}" ]; then
    REPO_VERSION='master'
    REPO_NAME='master'
else
    REPO_VERSION=$(sed 's/\.//' <<< ${GIT_VERSION})
    REPO_NAME=${GERRIT_BRANCH}
fi

cat > /srv/gluster/nightly/${REPO_NAME}.repo <<< "[gluster-nightly-${REPO_VERSION}]
name=Gluster Nightly builds (${GERRIT_BRANCH} branch)
baseurl=http://artifacts.ci.centos.org/gluster/nightly/${GERRIT_BRANCH}/\$releasever/\$basearch
enabled=1
gpgcheck=0"

pushd /srv/gluster/nightly
artifact ${REPO_NAME}.repo
artifact ${GERRIT_BRANCH}
popd
