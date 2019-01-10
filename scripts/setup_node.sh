#!/bin/bash

set -x
rm -rf /tmp/setupnode
mkdir -p /tmp/setupnode
cd /tmp/setupnode

KERNEL=$(uname -r)
sudo yum install -y kernel-devel-${KERNEL}
if [ $? -eq 1 ]
then
KERNEL=3.10.0-862.el7.x86_64
sudo rpm -i http://vault.centos.org/7.5.1804/os/x86_64/Packages/kernel-devel-${KERNEL}.rpm
fi

sudo yum install -y python-devel
sudo yum install -y redhat-rpm-config rpm-build gcc-gfortran gcc-c++
sudo yum install -y gtk2 atk cairo tcl tk createrepo wget
wget http://content.mellanox.com/ofed/MLNX_OFED-4.5-1.0.1.0/MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64.tgz
tar zxvf MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64.tgz

sudo ./MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64/mlnxofedinstall --kernel-sources /usr/src/kernels/$KERNEL --add-kernel-support --skip-repo


sudo sed -i 's/LOAD_EIPOIB=no/LOAD_EIPOIB=yes/g' /etc/infiniband/openib.conf
sudo /etc/init.d/openibd restart


sudo yum install -y python-setuptools
sudo yum install -y git
git clone https://github.com/Azure/WALinuxAgent.git
cd WALinuxAgent
sudo python setup.py install --register-service --force
sudo sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
sudo sed -i -e 's/AutoUpdate.Enabled=y/# AutoUpdate.Enabled=y/g' /etc/waagent.conf
sudo systemctl restart waagent

# pre-reqs for mpi
sudo yum install -y numactl numactl-devel libxml2-devel byacc

# disable firewall
sudo systemctl stop firewalld
