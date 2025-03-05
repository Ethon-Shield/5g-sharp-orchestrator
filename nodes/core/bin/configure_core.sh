#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.3
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${NRCORE_WORKING_DIR}/bin/general_functions.sh

######################################################
# Configure ostun interface for Open5gs NRCORE technology
#
# Globals:
#   NRCORE_IP_ADDRESS
# Arguments:
#   None
# Outputs:
#   Generate logs that are written to main log file
######################################################

function configure_ogstun {
  logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Configuring ogstun interface for Open5gs core deployment"
  ogstun_exists=$(grep -c "ogstun" /proc/net/dev)
  if [[ "${ogstun_exists}" -eq 0 ]]; then
    logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Creating ogstun interface..."
    sudo ip tuntap add name ogstun mode tun
  else
    logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "ogstun interface already created"
  fi
  correct_conf=1

  sudo ip addr del 10.45.0.1/16 dev ogstun 2> /dev/null
  sudo ip addr add 10.45.0.1/16 dev ogstun

  sudo ip addr del 2001:db8:cafe::1/48 dev ogstun 2> /dev/null
  sudo ip addr add 2001:db8:cafe::1/48 dev ogstun

  sudo ip link set ogstun up

  check_ip_ogstun=$(ifconfig | awk '/ogstun:/ {flag=1} /inet / && flag {print $2; flag=0}')
  check_mask_ogstun=$(ifconfig | awk '/ogstun:/ {flag=1} /inet / && flag {print $4; flag=0}')
  if [[ "${check_ip_ogstun}" == "10.45.0.1" ]] && [[ "${check_mask_ogstun}" == "255.255.0.0" ]];then
    logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "IPv4 configured for ogstun interface"
  else
    logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Error configuring IPv4 for ogstun interface"
    correct_conf=0
  fi

  check_ip6_ogstun=$(ifconfig | grep -c 2001:db8:cafe::1)
  if [[ "${check_ip6_ogstun}" -eq 1 ]];then
    logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "IPv6 configured for ogstun interface"
  else
    logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Error configuring IPv6 for ogstun interface"
    correct_conf=0
  fi


  if [[ "${correct_conf}" -eq 1 ]]; then
    logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "ogstun interface configured correctly"
  else
    logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Some error in ogstun configuration. Aborting process."
    exit 1
  fi


}


### ENABLE IP ROUTING 

sudo sysctl net.ipv4.conf.all.forwarding=1 >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initial_conf.log  2>&1
ipv4_forwarding=$(sysctl net.ipv4.conf.all.forwarding | cut -d= -f2 ) 
sudo iptables -P FORWARD ACCEPT  >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initial_conf.log  2>&1
iptables_forward=$( sudo iptables -S | grep -- '-P FORWARD' | awk '{print $3}' ) 
if [[ ${ipv4_forwarding} -eq 1 ]] && [[ "${iptables_forward}" == "ACCEPT" ]]; then  
  logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Enabled IP Routing among interfaces"
else 
  logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Some error configuring. Please check initial_conf.log"
  exit 1
fi 

### ENABLE OGSTUN DEV 

if [[ "${NRCORE_TECH}" == "OPEN5GS" ]]; then
  configure_ogstun >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initial_conf.log 2>&1
  if [[ $? -eq 1 ]]; then
    exit 1
  fi
fi
