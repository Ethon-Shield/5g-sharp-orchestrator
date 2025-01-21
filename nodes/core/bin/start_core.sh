#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.1
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${NRCORE_WORKING_DIR}/bin/general_functions.sh

CURRENT_DIR=$(pwd)

logging "INFO" "CORE" "${NRCORE_IP_ADDRESS}" "Deploying NRCORE instance"

if [[ "${NRCORE_TECH}" == "OAI" ]]; then

  cd ${NRCORE_DOCKER_COMPOSE_WD} 

  logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Deploying OAI NRCORE - Basic deployment with upf"
  sudo python3 core-network.py --type start-basic  > ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log 2>&1

  tshark -i demo-oai -f "(not host 192.168.70.135 and not arp and not port 53 and not port 2152) or (host 192.168.70.135 and icmp)" -w ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/nrcore_network.pcap &
  cd ${CURRENT_DIR}

else

  logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Deploying Open5GS NRCORE"

  # Iniciar captura de tráfico en el interfaz de loopback
  tshark -i lo -w ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/nrcore_network.pcap &

  for binary in "${NR_BIN_INDEX[@]}"
  do
    BIN_PATH=${NRCORE_OPEN5GS_WD}/install/bin/${binary}	  
    CONF_PATH=${NRCORE_WORKING_DIR}/conf/open5gs/${NR_BIN_CONF[${binary}]}
    LOG_PATH=${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/${NR_BIN_LOG[${binary}]}
    echo "" > ${LOG_PATH}

    if [[ -f ${BIN_PATH} ]]; then
      if [[ -f ${CONF_PATH} ]]; then
        echo ""
        echo "Starting ${NR_BIN_NAME[${binary}]}..."
        ${BIN_PATH} -c ${CONF_PATH} > /dev/null 2>&1 &
        sleep 1
        node_ini=$(cat ${LOG_PATH} | grep -c "${NR_BIN_NAME[${binary}]} initialize...done")
        if [[ ${node_ini} -eq 1 ]]; then
          echo "${NR_BIN_NAME[${binary}]} active!"
        else
          echo "Error starting ${NR_BIN_NAME[${binary}]}"
          exit 1
        fi
      else
        echo "ERROR: Configuration file not found in ${CONF_PATH}"
        exit 1
      fi
    else
      echo "ERROR: Binary ${binary} not found in ${BIN_DIR}"
      exit 1
    fi
  done
fi
