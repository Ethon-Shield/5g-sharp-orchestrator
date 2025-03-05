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

CURRENT_DIR=$(pwd)

logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Undeploying NRCORE instance" 

if [[ "${NRCORE_TECH}" == "OAI" ]]; then

  cd ${NRCORE_DOCKER_COMPOSE_WD}
  sudo python3 core-network.py --type stop-basic
  cd ${CURRENT_DIR}

else
  stop_process "open5gs"
  stop_process "${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/nrcore_network.pcap"
fi
