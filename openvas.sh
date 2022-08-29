#!/bin/bash

echo !! STARTING INSTALLATION AND !!
echo !! OPENVAS CONFIGURATION !!
echo
echo
echo !! PREPARING ENVIRONMENT !! 
apt update && apt upgrade -y && apt install vim aptitude lsb-release -y
echo
echo
echo !! CREATION OF A USER WITHOUT PRIVILEGE !! 
useradd -r -d /opt/gvm -c "GVM User" -s /bin/bash gvm
echo
echo
echo  !! DIRECTORY CREATION !! 
mkdir /opt/gvm && chown gvm: /opt/gvm
#chown gvm: /var/lib/gvm
echo
echo
echo  !! DEPENDENCE INSTALLATION !! 
apt install gcc g++ wget make bison flex libksba-dev curl redis libpcap-dev cmake git pkg-config libglib2.0-dev libgpgme-dev nmap libgnutls28-dev uuid-dev libssh-gcrypt-dev libldap2-dev gnutls-bin libmicrohttpd-dev libhiredis-dev zlib1g-dev libxml2-dev libnet-dev libradcli-dev clang-format libldap2-dev doxygen gcc-mingw-w64 xml-twig-tools libical-dev perl-base heimdal-dev libpopt-dev libunistring-dev graphviz libsnmp-dev python3-setuptools python3-paramiko python3-lxml python3-defusedxml python3-dev gettext python3-polib xmltoman python3-pip texlive-fonts-recommended texlive-latex-extra --no-install-recommends xsltproc sudo vim rsync -y
echo
echo
echo  !! YARN JAVASCRIPT PACKAGE MANAGER INSTALLATION !! 
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg |gpg --dearmor |sudo tee /usr/share/keyrings/yarnkey.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
apt update && apt install yarn -y
echo
echo
echo !! POSTGRESQL INSTALLATION !! 
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt update && apt install postgresql-11 postgresql-contrib-11 postgresql-server-dev-11 -y
echo
echo
echo  !! CREATING USER AND BASE IN POSTGRESQL !! 
#sudo -Hiu postgres
sudo -Hiu postgres createuser gvm
sudo -Hiu postgres createdb -O gvm gvmd
echo
echo
echo  !! GIVING USER PERMISSIONS IN POSTGRESQL !! 
sudo -Hiu postgres psql gvmd <<EOF
create role dba with superuser noinherit;
grant dba to gvm;
\q
EOF
echo
echo
echo  !! RESTART POSTGRESQL !! 
systemctl restart postgresql && systemctl enable postgresql

echo "gvm ALL = NOPASSWD: $(which make) install" > /etc/sudoers.d/gvm

aptitude install libpaho-mqtt1.3 libpaho-mqtt-dev -y
apt install libjson-glib-dev libbsd-dev -y
echo
echo
echo !! BUILDING GVM 21.04 !! 
su - gvm <<EOF
mkdir gvm-source && cd /opt/gvm/gvm-source
echo
echo
echo !! USING GIT CLONE !!
git clone -b stable --single-branch https://github.com/greenbone/gvm-libs.git
git clone -b main --single-branch https://github.com/greenbone/openvas-smb.git
git clone -b stable --single-branch https://github.com/greenbone/openvas.git
git clone -b stable --single-branch https://github.com/greenbone/ospd.git
git clone -b stable --single-branch https://github.com/greenbone/ospd-openvas.git
git clone -b stable --single-branch https://github.com/greenbone/gvmd.git
git clone -b stable --single-branch https://github.com/greenbone/gsad.git
git clone -b stable --single-branch https://github.com/greenbone/gsa.git
git clone -b stable --single-branch https://github.com/greenbone/pg-gvm.git
echo
echo
echo !! CLONE THE GSA !! 
#wget https://github.com/greenbone/gsa/archive/refs/tags/v21.4.3.tar.gz -O gsa.tar.gz
#tar -xzf gsa.tar.gz && mv gsa-21.4.3/ gsa/
echo
echo
echo !! BUILDING AND INSTALLING LIBRARIES GVM !! 
cd gvm-libs && mkdir build && cd build
cmake ..
make
sudo make install
echo
echo
echo !! BUILDING AND INSTALLING SCANNER OPENVAS E OPENVAS SMB !! 
cd /opt/gvm/gvm-source/openvas-smb/
mkdir build && cd build
cmake ..
make
sudo make install

cd /opt/gvm/gvm-source/openvas/
mkdir build && cd build
cmake ..
make
sudo make install
echo
exit
EOF

ldconfig
cp /opt/gvm/gvm-source/openvas/config/redis-openvas.conf /etc/redis/
chown redis:redis /etc/redis/redis-openvas.conf
echo "db_address = /run/redis-openvas/redis.sock" > /etc/openvas/openvas.conf
usermod -aG redis gvm
echo "net.core.somaxconn = 1024" >> /etc/sysctl.conf
echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
sysctl -p

echo !! CREATE THE SERVICE DISABLE_THP !! 
cat > /etc/systemd/system/disable_thp.service << 'EOL'
[Unit]
Description=Desativar suporte de kernel para páginas enormes transparentes (THP)

[Service]
Type=simple
ExecStart = /bin/sh -c "echo 'never'> /sys/kernel/mm/transparent_hugepage/enabled && echo 'never'> /sys/kernel/mm/transparent_hugepage/defrag"

[Install]
WantedBy=multi-user.target
EOL

echo !! RESTART AND SERVICE REDIS-SERVER !!
systemctl daemon-reload
systemctl enable --now disable_thp
systemctl enable --now redis-server@openvas
#systemctl status redis-server@openvas


echo !! UPDATE OF NETWORK VULNERABILITY TESTS !!
mkdir /var/lib/notus && chown -R gvm: /var/lib/notus
chown -R gvm: /var/lib/openvas/
echo "gvm ALL = NOPASSWD: $(which openvas)" >> /etc/sudoers.d/gvm
su - gvm <<EOF
greenbone-nvt-sync
#/usr/local/bin/greenbone-nvt-sync

sudo openvas --update-vt-info

echo !! INSTALLING GREENBONE VULNERABILITY MANAGER !!
cd /opt/gvm/gvm-source/gvmd
mkdir build && cd build
cmake ..
make
sudo make install

echo !! INSTALLING EXTENSION PG-GVM !!
cd /opt/gvm/gvm-source/pg-gvm
mkdir build && cd build
cmake ..
make
sudo make install
exit
EOF

echo !! CONFIGURING NODEJS AND YARN !!
echo !! INSTALLING NODEJS 14.X !!

curl -sL https://deb.nodesource.com/setup_14.x | bash -
apt update && apt upgrade
apt install nodejs -y

echo !! INSTALLING GREENBONE SECURITY ASSISTANT !!
su - gvm <<EOF
cd /opt/gvm/gvm-source/gsa
rm -rf build
yarn
yarn build

echo !! INSTALLING GREENBONE SECURITY ASSISTANT HTTP SERVER !!
cd ../gsad
mkdir build && cd build
cmake ..
make
sudo make install
exit
EOF

[[ -d /usr/local/share/gvm/gsad/web ]] || mkdir -p /usr/local/share/gvm/gsad/web

chown -R gvm: /usr/local/share/gvm/gsad/web

cp -rp /opt/gvm/gvm-source/gsa/build/* /usr/local/share/gvm/gsad/web

echo
echo
echo !! UPDATING THE MODULES !!
chown -R gvm: /var/lib/gvm/

sudo -u gvm greenbone-feed-sync --type GVMD_DATA

sudo -u gvm greenbone-feed-sync --type SCAP

sudo -u gvm greenbone-feed-sync --type CERT

echo
echo
echo !! GENERATING CERT GVM !!
sudo -u gvm gvm-manage-certs -a

echo
echo
echo !! INSTALLING OSPD AND OSPD-OPENVAS !!
su - gvm <<EOF
pip3 install wheel
pip3 install python-gvm gvm-tools

cd /opt/gvm/gvm-source/ospd
python3 -m pip install .

cd /opt/gvm/gvm-source/ospd-openvas
python3 -m pip install .
exit
EOF

echo
echo
echo !! CREATING SERVICE OPENVAS OSPD !!
cat > /etc/systemd/system/ospd-openvas.service << 'EOL'
[Unit]
Description=OSPd Wrapper for the OpenVAS Scanner (ospd-openvas)
After=network.target networking.service redis-server@openvas.service postgresql.service
Wants=redis-server@openvas.service
ConditionKernelCommandLine=!recovery

[Service]
ExecStartPre=-rm -rf /var/run/gvm/ospd-openvas.pid /var/run/gvm/ospd-openvas.sock
Type=simple
User=gvm
Group=gvm
RuntimeDirectory=gvm
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/opt/gvm/bin:/opt/gvm/sbin:/opt/gvm/.local/bin
ExecStart=/opt/gvm/.local/bin/ospd-openvas \
--pid-file /var/run/gvm/ospd-openvas.pid \
--log-file /var/log/gvm/ospd-openvas.log \
--lock-file-dir /var/run/gvm -u /var/run/gvm/ospd-openvas.sock
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

[[ -d /var/run/gvm ]] || mkdir /var/run/gvm

chown -R gvm: /var/run/gvm /var/log/gvm

systemctl daemon-reload

systemctl enable --now ospd-openvas

echo
echo
echo !! CREATE SERVICE GVM SERVICES !!
cp /lib/systemd/system/gvmd.service{,.bak}

cat > /lib/systemd/system/gvmd.service << 'EOL'
[Unit]
Description=Greenbone Vulnerability Manager daemon (gvmd)
After=network.target networking.service postgresql.service ospd-openvas.service
Wants=postgresql.service ospd-openvas.service
Documentation=man:gvmd(8)
ConditionKernelCommandLine=!recovery

[Service]
Type=forking
User=gvm
Group=gvm
RuntimeDirectory=gvmd
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/opt/gvm/bin:/opt/gvm/sbin:/opt/gvm/.local/bin
ExecStart=/usr/local/sbin/gvmd --osp-vt-update=/var/run/gvm/ospd-openvas.sock
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable --now gvmd

echo
echo
echo !! CREATING SERVICE GSA SERVICES !!
cp /lib/systemd/system/gsad.service{,.bak}

cat > /lib/systemd/system/gsad.service << 'EOL'
[Unit]
Description=Greenbone Security Assistant daemon (gsad)
Documentation=man:gsad(8) https://www.greenbone.net
After=network.target gvmd.service
Wants=gvmd.service

[Service]
Type=simple
User=gvm
Group=gvm
RuntimeDirectory=gsad
PIDFile=/var/run/gsad/gsad.pid
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/opt/gvm/bin:/opt/gvm/sbin:/opt/gvm/.local/bin
ExecStart=/usr/bin/sudo /usr/local/sbin/gsad -k /var/lib/gvm/private/CA/clientkey.pem -c /var/lib/gvm/CA/clientcert.pem
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

echo "gvm ALL = NOPASSWD: $(which gsad)" >> /etc/sudoers.d/gvm

systemctl daemon-reload
systemctl enable --now gsad

echo
echo
echo !! CREATING GVM SCANNER !!

sudo -u gvm gvmd --create-scanner="MYScan-demo OpenVAS Scanner" --scanner-type="OpenVAS" --scanner-host=/var/run/gvm/ospd-openvas.sock

echo
echo
echo !! CREATING GVM ADMIN USER !!
sudo -u gvm gvmd --create-user admin

### COMMANDS EXTRAS
# VERIFY THE SCANS CREATED
#sudo -u gvm gvmd --get-scanners

# CREATING NEW USERS
#sudo -u gvm gvmd --create-user USER

# CREATION OF NEW USERS WITH PASSWORD
#sudo -u gvm gvmd --create-user USERNAME --password=PASSWORD

# CHANGING USER PASSWORDS
#sudo -u gvm gvmd --user=<USERNAME> --new-password=<PASSWORD>