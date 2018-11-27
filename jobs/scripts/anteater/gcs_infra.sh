#!/bin/bash

# if anything fails, we'll abort
set -e

# TODO: disable debugging
set -x

echo "##### Hypervisor setup #####"

# Install hypervisor
yum -y install qemu qemu-kvm qemu-kvm-tools qemu-img libvirt libvirt-daemon-kvm libvirt-client

# Vagrant needs libvirtd running
systemctl enable libvirtd.service
systemctl start libvirtd.service
systemctl status libvirtd.service

# Log the virsh capabilites so that we know the
# environment in case something goes wrong.
virsh capabilities

echo "##### Vagrant setup #####"

# Install vagrant from vagrantup.com rather than SCL as the scripts from GCS
# repo cannot be modified
# https://www.hashicorp.com/security.html
HASHIECORP_GPG_KEY="-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

mQENBFMORM0BCADBRyKO1MhCirazOSVwcfTr1xUxjPvfxD3hjUwHtjsOy/bT6p9f
W2mRPfwnq2JB5As+paL3UGDsSRDnK9KAxQb0NNF4+eVhr/EJ18s3wwXXDMjpIifq
fIm2WyH3G+aRLTLPIpscUNKDyxFOUbsmgXAmJ46Re1fn8uKxKRHbfa39aeuEYWFA
3drdL1WoUngvED7f+RnKBK2G6ZEpO+LDovQk19xGjiMTtPJrjMjZJ3QXqPvx5wca
KSZLr4lMTuoTI/ZXyZy5bD4tShiZz6KcyX27cD70q2iRcEZ0poLKHyEIDAi3TM5k
SwbbWBFd5RNPOR0qzrb/0p9ksKK48IIfH2FvABEBAAG0K0hhc2hpQ29ycCBTZWN1
cml0eSA8c2VjdXJpdHlAaGFzaGljb3JwLmNvbT6JATgEEwECACIFAlMORM0CGwMG
CwkIBwMCBhUIAgkKCwQWAgMBAh4BAheAAAoJEFGFLYc0j/xMyWIIAIPhcVqiQ59n
Jc07gjUX0SWBJAxEG1lKxfzS4Xp+57h2xxTpdotGQ1fZwsihaIqow337YHQI3q0i
SqV534Ms+j/tU7X8sq11xFJIeEVG8PASRCwmryUwghFKPlHETQ8jJ+Y8+1asRydi
psP3B/5Mjhqv/uOK+Vy3zAyIpyDOMtIpOVfjSpCplVRdtSTFWBu9Em7j5I2HMn1w
sJZnJgXKpybpibGiiTtmnFLOwibmprSu04rsnP4ncdC2XRD4wIjoyA+4PKgX3sCO
klEzKryWYBmLkJOMDdo52LttP3279s7XrkLEE7ia0fXa2c12EQ0f0DQ1tGUvyVEW
WmJVccm5bq25AQ0EUw5EzQEIANaPUY04/g7AmYkOMjaCZ6iTp9hB5Rsj/4ee/ln9
wArzRO9+3eejLWh53FoN1rO+su7tiXJA5YAzVy6tuolrqjM8DBztPxdLBbEi4V+j
2tK0dATdBQBHEh3OJApO2UBtcjaZBT31zrG9K55D+CrcgIVEHAKY8Cb4kLBkb5wM
skn+DrASKU0BNIV1qRsxfiUdQHZfSqtp004nrql1lbFMLFEuiY8FZrkkQ9qduixo
mTT6f34/oiY+Jam3zCK7RDN/OjuWheIPGj/Qbx9JuNiwgX6yRj7OE1tjUx6d8g9y
0H1fmLJbb3WZZbuuGFnK6qrE3bGeY8+AWaJAZ37wpWh1p0cAEQEAAYkBHwQYAQIA
CQUCUw5EzQIbDAAKCRBRhS2HNI/8TJntCAClU7TOO/X053eKF1jqNW4A1qpxctVc
z8eTcY8Om5O4f6a/rfxfNFKn9Qyja/OG1xWNobETy7MiMXYjaa8uUx5iFy6kMVaP
0BXJ59NLZjMARGw6lVTYDTIvzqqqwLxgliSDfSnqUhubGwvykANPO+93BBx89MRG
unNoYGXtPlhNFrAsB1VR8+EyKLv2HQtGCPSFBhrjuzH3gxGibNDDdFQLxxuJWepJ
EK1UbTS4ms0NgZ2Uknqn1WRU1Ki7rE4sTy68iZtWpKQXZEJa0IGnuI2sSINGcXCJ
oEIgXTMyCILo34Fa/C6VCm2WBgz9zZO8/rHIiQm1J5zqz0DrDwKBUM9C
=LYpS
-----END PGP PUBLIC KEY BLOCK-----"
echo "$HASHIECORP_GPG_KEY" > hashicorp.asc
rpm --import hashicorp.asc
curl -Os 'https://releases.hashicorp.com/vagrant/2.2.1/vagrant_2.2.1_x86_64.rpm'
curl -Os 'https://releases.hashicorp.com/vagrant/2.2.1/vagrant_2.2.1_SHA256SUMS'
curl -Os 'https://releases.hashicorp.com/vagrant/2.2.1/vagrant_2.2.1_SHA256SUMS.sig'
gpg --verify vagrant_2.2.1_SHA256SUMS.sig vagrant_2.2.1_SHA256SUMS
yum -y install perl-Digest-SHA # For /usr/bin/shasum
shasum -a 256 -c vagrant_2.2.1_SHA256SUMS
yum -y localinstall vagrant_2.2.1_x86_64.rpm

echo "##### vagrant-libvirt setup #####"
# https://github.com/vagrant-libvirt/vagrant-libvirt
yum -y install libvirt-devel ruby-devel gcc \
  libxslt-devel libxml2-devel libguestfs-tools-c
vagrant plugin install vagrant-libvirt

# Log the available vagrant plugins
vagrant plugin list

# Import the vagrant box
vagrant box add centos/atomic-host

echo "##### GCS setup #####"
# Clone the GCS repo
# kubespray is pulled in as a git submodule, via --recursive
git clone --recursive https://github.com/gluster/gcs.git
pushd gcs

# Prepare for vagrant based deployment
pushd deploy
./prepare.sh

# Activate the created virtualenv
source gcs-venv/bin/activate

# List installed pip modules for debugging and to ensure we're in the
# virtualenv
pip list

vagrant up
