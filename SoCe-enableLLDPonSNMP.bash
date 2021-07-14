#!/bin/bash
# Script zum recompilieren von LLDP mit SNMP Unterstützung in SoC-e TSN Switches
# Zuerst muss den command ssh-keygen -t rsa -b 2048 durchgeführt worden sein
# Ersten Argument IP-Adresse

# Save SUDO password in $passwd
echo "Enter SUDO password:"
read passwd
echo "SUDO password saved"

# Copy ssh id to ease connection
echo "Ssh-copy-id"
ssh-copy-id soc-e@$1 2>/dev/null

# First upgrade for certificates
echo $passwd | ssh -tt soc-e@$1 "sudo apt-get update; sudo apt-get upgrade -y; sudo reboot"

sleep 1m

# Reinstall LLDP with SNMP compatibility

## Install GIT
echo $passwd | ssh -tt soc-e@$1 "sudo apt-get install -y git"

## Get repository LLDP master and compile with SNMP option 
ssh soc-e@$1 'bash -s' <<'ENDSSH'
  mkdir -p /home/soc-e/lldpd
  cd /home/soc-e/lldpd
  git clone https://github.com/lldpd/lldpd
  cd /home/soc-e/lldpd/lldpd
  ./autogen.sh
  ./configure --with-snmp
  make
ENDSSH

## Install fresh compiled LLDP
echo $passwd | ssh -tt soc-e@$1 "cd /home/soc-e/lldpd/lldpd && sudo killall -9 lldpd && sudo make install"


# Edit snmp.comf.template to add all OIDs to view
FILE_SNMP=/etc/spt_service/configs/current/snmpd.conf.template
echo $passwd | ssh -tt soc-e@$1 "sudo sed -i '/^view[ ]\+soceview[ ]\+included[ ]\+\.1$/d;/^\# MIB view$/aview   soceview  included   .1' $FILE_SNMP"

# Edit snmp.comf.template to add all OIDs to view
FILE_LLDP=/lib/systemd/system/lldpd.service
echo $passwd | ssh -tt soc-e@$1 "sudo sed -i 's/^ExecStart=\/usr\/local\/sbin\/lldpd \$DAEMON_ARGS \$LLDPD_OPTIONS$/ExecStart=\/usr\/local\/sbin\/lldpd -O \/etc\/lldpd.conf -x \$DAEMON_ARGS \$LLDPD_OPTIONS/' $FILE_LLDP"
echo $passwd | ssh -tt soc-e@$1 "sudo systemctl daemon-reload; sudo service lldpd restart"

# Install BRIDGE-MIB with perl and systemd

## Install libsnmp-perl
echo $passwd | ssh -tt soc-e@$1 "sudo apt-get install -y libsnmp-perl"

## Create script with perl command
ssh soc-e@$1 'bash -s' <<'ENDSSH'
mkdir -p /home/soc-e/bridge-mib
touch /home/soc-e/bridge-mib/snmp-bridge-mib.sh
cat << EOF > /home/soc-e/bridge-mib/snmp-bridge-mib.sh
#!/bin/bash  
perl /usr/bin/snmp-bridge-mib br0
EOF
chmod +x /home/soc-e/bridge-mib/snmp-bridge-mib.sh
ENDSSH

## Move script to destination with SUDO
echo $passwd | ssh -tt soc-e@$1 'sudo cp /home/soc-e/bridge-mib/snmp-bridge-mib.sh /usr/sbin/snmp-bridge-mib.sh && sudo chown root:root /usr/sbin/snmp-bridge-mib.sh'

## Create unit file for systemd
ssh soc-e@$1 'bash -s' <<'ENDSSH'
touch /home/soc-e/bridge-mib/snmp-bridge-mib.service
cat << EOF > /home/soc-e/bridge-mib/snmp-bridge-mib.service
[Unit]
Description=snmp-bridge-mib script

[Service]
ExecStart=/usr/sbin/snmp-bridge-mib.sh

[Install]
WantedBy=multi-user.target
EOF
ENDSSH

## Move unit file to destination and enable and start service with SUDO
echo $passwd | ssh -tt soc-e@$1 'sudo cp /home/soc-e/bridge-mib/snmp-bridge-mib.service /etc/systemd/system/snmp-bridge-mib.service && sudo chown root:root /etc/systemd/system/snmp-bridge-mib.service && sudo systemctl enable snmp-bridge-mib && sudo systemctl start snmp-bridge-mib'


passwd=''

echo "Done!!!"
