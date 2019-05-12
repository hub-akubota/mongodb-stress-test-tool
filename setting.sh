#!/bin/bash
# Usage : ./setting.sh [install dir(optional)]

##################################
# installer based on db_install.sh
set -e

LOGFILE="instlog."`date "+%Y%m%d_%H%M%S"`
exec 2>&1> >(awk '{print strftime("[%Y-%m-%d %H:%M:%S] "),$0 } { fflush() } ' | tee $LOGFILE)

trap 'echo ""; echo "Installation stopped by SIGINT!!"; echo "You may be in unknown state."; echo "Check ${LOGFILE} for debugging in case of a problem of re-executing this script."; exit 1' 2

instdir=${1}
if [ -z "${instdir}" ]; then
    instdir="./Yarr"
fi
if [ -e "$instdir" ]; then
    echo "ERROR: Specified directory already exists: ${instdir}"
    echo "Exitting..."
    exit 1
else
    echo "Yarr software will be installed in: ${instdir}"
fi

#installing necessary packages if not yet installed
echo "Start installing necessary packages..."
#adding mongoDB repository and installing mongoDB
if [ -e "/etc/yum.repos.d/mongodb-org-3.6.repo" ]; then
    echo "mongodb-org-3.6 repository already installed. Nothing to do."
else
    echo "Adding mongodb-org-3.6 repository."
    sudo sh -c "echo \"[mongodb-org-3.6]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/7Server/mongodb-org/3.6/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.6.asc\" > /etc/yum.repos.d/mongodb-org-3.6.repo"
fi
packages=(
    "epel-release.noarch"
    "centos-release-scl.noarch"
    "bc.x86_64"
    "wget.x86_64"
    "rh-mongodb36-mongo-cxx-driver-devel.x86_64"
    "rh-mongodb36-boost-devel.x86_64"
    "mongodb-org.x86_64"
    "devtoolset-7.x86_64"
    "gnuplot.x86_64"
    "python.x86_64"
    "python27-python-pip.noarch"
    "poppler-utils.x86_64"
    "httpd.x86_64"
)
for pac in ${packages[@]}; do
    if yum info ${pac} | grep "Installed Packages" > /dev/null; then
        echo "${pac} already installed. Nothing to do."
    else
        echo "${pac} not found. Starting to install..."
        sudo yum install -y ${pac}
    fi
done

#enabling RedHad SCL packages
scl_sw=(
    "devtoolset-7"
    "python27"
    "rh-mongodb36"
)
for sw in ${scl_sw[@]}; do
    echo "Checking if ${sw} is already enabled in .bashrc..."
    if grep "source /opt/rh/${sw}/enable" ~/.bashrc > /dev/null; then
        echo "Already setup. Nothing to do."
    else
        echo "Not found. Adding a source command in your .bashrc"
        echo -e "\n#added by the mongoDB install script" >> ~/.bashrc
        echo "source /opt/rh/${sw}/enable" >> ~/.bashrc
    fi
    source /opt/rh/${sw}/enable
done

#install python packages by pip for the DB viewer
packages=(
    "Flask-PyMongo"
    "pdf2image"
    "Pillow"
    "python-dateutil"
    "Flask-HTTPAuth"
    "pyyaml"
)
for pac in ${packages[@]}; do
    if pip show ${pac} | grep "Name: ${pac}" > /dev/null; then
        echo "${pac} already installed. Nothing to do."
    else
        echo "${pac} not found. Starting to install..."
        sudo pip install ${pac}
    fi
done

#downloading Yarr-sw 
echo ""
echo "Start cloning the Yarr software..."
git clone https://github.com/jlab-hep/Yarr.git $instdir
cd $instdir
git checkout database-devel

#compiling Yarr-sw
echo ""
echo "Starting compilation of the Yarr software."
ncpu=`cat /proc/cpuinfo | grep processor| wc -l`
cd src
make -j${ncpu}
cd ../../

#installing CERN ROOT if it's not setup.
echo ""
echo "Start checking if the ROOT software is available..."
rootloc+=`pwd`/"root/bin/thisroot.sh"
if which root 2>&1| grep "no root in" > /dev/null; then
    if [ -e ./root/bin ]; then
        echo "ROOT directory was found. Skip downloading it..."
    else
        echo "ROOT not found. Downloading the pre-compiled version of 6.14.06..."
        wget https://root.cern.ch/download/root_v6.14.06.Linux-centos7-x86_64-gcc4.8.tar.gz
        tar zxf root_v6.14.06.Linux-centos7-x86_64-gcc4.8.tar.gz
        rm -f root_v6.14.06.Linux-centos7-x86_64-gcc4.8.tar.gz
    fi
    if grep "thisroot.sh" ~/.bashrc > /dev/null; then
        echo "thisroot.sh is already sourced in your .bashrc."
    else
        echo -e "\n#added by the mongoDB install script" >> ~/.bashrc
        echo "source ${rootloc}" >> ~/.bashrc
    fi
    source root/bin/thisroot.sh
else
    echo "ROOT was found. Checking if PyROOT is available"
    pyroot_found="false"
    for ii in 1 2 3 4; do
	if pydoc modules | cut -d " " -f${ii} | grep -x ROOT > /dev/null; then
	    pyroot_found="true"
	fi
    done
    if [ ${pyroot_found} != "true" ]; then
	echo "WARNING: PyROOT is not available."
	echo "Check if PYTHONPATH is properly set or if you compiled ROOT with the PyROOT option enabled."
	echo "You need a manual fix to enable some features in the viewer."
    else
	echo "PyROOT is available in your environment."
    fi
fi

#Preparing database directory
echo ""
echo "Preparing initial data in yarrdb..."
sudo systemctl stop mongod
if [ -e /var/lib/mongo ]; then
    today=`date +%y%m%d`
    echo "Found /var/lib/mongo. Backing up the contents in /var/lib/mongo-${today}.tar.gz..."
    cd /var/lib
    sudo tar zcf mongo-${today}.tar.gz mongo
    cd - > /dev/null
    sudo rm -rf /var/lib/mongo
else
    sudo mkdir -p /var/lib
fi
sudo chcon -R -u system_u -t mongod_var_lib_t /var/lib/mongo/
sudo chown -R mongod:mongod /var/lib/mongo

starting and enabling DB and http servers
services=(
    "mongod"
)
for svc in ${services[@]}; do
    echo ""
    echo "Setting up ${svc}..."
    if systemctl status ${svc} | grep running > /dev/null; then
        echo "${svc} is already running. Nothing to do."
    else
        echo "Starting ${svc} on your local machine."
        sudo systemctl start ${svc}
    fi
    if systemctl list-unit-files -t service|grep enabled | grep ${svc} > /dev/null; then
        echo "${svc} is already enabled. Nothing to do."
    else
        echo "Enabling ${svc} on your local machine."
        sudo systemctl enable ${svc}
    fi
done

#Needed to avoid tons of warnings by mongod in /var/log/messages
sudo ausearch -c 'ftdc' --raw | sudo audit2allow -M my-ftdc
sudo semodule -i my-ftdc.pp

ip=`ip -f inet -o addr show| grep -e en -e eth|cut -d\  -f 7 | cut -d/ -f 1`
echo ""
echo "Finished installation!!"
echo "Install log can be found in: $LOGFILE"
echo ""
echo "----------------------------------------------------------------"
echo "-- First thing to do..."
echo "----------------------------------------------------------------"
echo "Please log-off and log-in again to activate environmental variables."
