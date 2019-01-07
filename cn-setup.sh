#!/bin/bash

# fail on any error
set -ex

HEADNODE=10.0.2.4

sed -i 's/^ResourceDisk.MountPoint=\/mnt\/resource$/ResourceDisk.MountPoint=\/mnt\/local_resource/g' /etc/waagent.conf
umount /mnt/resource

mkdir -p /mnt/resource/scratch

cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               soft    nofile          65535
*               soft    nofile          65535
EOF

cat << EOF >> /etc/fstab
$HEADNODE:/home    /home   nfs defaults 0 0
$HEADNODE:/mnt/resource/scratch    /mnt/resource/scratch   nfs defaults 0 0
EOF

#yum --enablerepo=extras install -y -q epel-release
#yum install -y -q nfs-utils htop pdsh psmisc
until yum install -y -q nfs-utils
do
    sleep 10
done
setsebool -P use_nfs_home_dirs 1

mount -a

# Don't require password for HPC user sudo
echo "hpcuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

KERNEL=$(uname -r)
yum install -y kernel-devel-${KERNEL}
if [ $? -eq 1 ]
then
KERNEL=3.10.0-862.el7.x86_64
rpm -i http://vault.centos.org/7.5.1804/os/x86_64/Packages/kernel-devel-${KERNEL}.rpm
fi

yum install -y python-devel
yum install -y redhat-rpm-config rpm-build gcc-gfortran gcc-c++
yum install -y gtk2 atk cairo tcl tk createrepo wget
wget --retry-connrefused --tries=3 --waitretry=5 http://content.mellanox.com/ofed/MLNX_OFED-4.5-1.0.1.0/MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64.tgz
tar zxvf MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64.tgz

./MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.5-x86_64/mlnxofedinstall --kernel-sources /usr/src/kernels/$KERNEL --add-kernel-support --skip-repo


sed -i 's/LOAD_EIPOIB=no/LOAD_EIPOIB=yes/g' /etc/infiniband/openib.conf
/etc/init.d/openibd restart


yum install -y python-setuptools
yum install -y git
git clone https://github.com/Azure/WALinuxAgent.git
cd WALinuxAgent
wget https://patch-diff.githubusercontent.com/raw/Azure/WALinuxAgent/pull/1365.patch
wget https://patch-diff.githubusercontent.com/raw/Azure/WALinuxAgent/pull/1375.patch
wget https://patch-diff.githubusercontent.com/raw/Azure/WALinuxAgent/pull/1389.patch
git reset --hard 72b643ea93e5258c3cec0e778017936806111f15
git config --global user.email "hpcuser@azure.com"
git config --global user.name "HPC User"
git am 1*.patch
python setup.py install --register-service --force
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
sed -i -e 's/AutoUpdate.Enabled=y/# AutoUpdate.Enabled=y/g' /etc/waagent.conf
systemctl restart waagent
