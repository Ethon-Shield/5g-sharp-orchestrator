#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.5
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${GNB_WORKING_DIR}/bin/general_functions.sh

######################################################
# Check connection between local machine and a specified node
#
# Globals:
#   GNB_WORKING_DIR
#   GNB_IP_ADDRESS
# Arguments:
#   remote= Name of the node to check connection to
#   ip_address= IP address of the node to check connection to
# Outputs:
#   Print the result of the check process to stdout
######################################################

function check_remote_connection {
  remote=$1
  ip_address=$2
  ping -c 5 ${ip_address} >> ${GNB_WORKING_DIR}/tmp/${remote}_ping.log  2>&1
  if [[ $? -eq 0 ]]; then
    logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "${remote} is reachable"
  elif [[ $? -eq 1 ]]; then
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "${remote} host is unreachable"
    exit 1
  elif [[ $? -eq 2 ]]; then
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "${remote} host is down or does not respond to ping"
    exit 1
  elif [[ $? -eq 68 ]]; then
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "Cannot resolve ${remote} host"
    exit 1
  else
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "Ping to ${remote} was NOT successfull, ping error code -> $?"
    exit 1
  fi
}

check_remote_connection "amf" ${AMF_IP_ADDRESS}
if [[ $? -eq 1 ]]; then
	logging "ERROR" "GNB " "${GNB_IP_ADDRESS}" "gNB cannot reach AMF - Please check Internet configuration and ip routes - Check if AMF IP address: ${AMF_IP_ADDRESS} is correct"
	exit 1
fi                                                             
