# CMF_SoC-e_postUpdate
Comprehensive Management Function: fix SNMP and LLDP post-update for SoC-e MTSN Kit Switch

The script connects per SSH using at first ssh-copy-id to ease the connection. Previous to run this script please run 'ssh-keygen -t rsa -b 2048'. The SUDO password is required to perform the installation and configuration of services and will be asked once at the beginning and saved in $passwd for the script run. The soc-e password will be also asked for the ssh-copy-id in the first run of the script.

Arguments:
- IP of the SoC-e Switch CLI
