#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.4
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${GNB_WORKING_DIR}/bin/general_functions.sh

check_gnb=0
recheck_gnb=0

logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "Received command to stop gNB instance"
ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPING\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
if [[ "${GNB_TECH}" == "OAI" ]]; then

  check_gnb=$(ps -ef | grep "${NR_SOFTMODEM_BIN} -O ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)

  if [[ ${check_gnb} -gt 0 ]]; then 
    
    stop_process "${NR_SOFTMODEM_BIN} -O ${GNB_CONFIG_FILE}" > /dev/null 
    sleep 3
    recheck_gnb=$(ps -ef | grep "${NR_SOFTMODEM_BIN} -O ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)
    if [[ ${recheck_gnb} -gt 0 ]]; then 
      logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "Some problem stopping gNB instance"
      ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"UNSTABLE\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
      echo 1
    else
      logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "gNB instance stopped correctly"
      ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
      echo 0
    fi
  else
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "Received command to stop gNB, but there was no process running"
    ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
    echo 0
  fi

else

  check_gnb=$(ps -ef | grep "${SRS_GNB_BIN} -c ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)

  if [[ ${check_gnb} -gt 0 ]]; then

    stop_process "${SRS_GNB_BIN} -c ${GNB_CONFIG_FILE}" > /dev/null
    sleep 1
    recheck_gnb=$(ps -ef | grep "${SRS_GNB_BIN} -c ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)
    if [[ ${recheck_gnb} -gt 0 ]]; then
      logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "gNB was not stopped correctly"
      ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"UNSTABLE\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
      echo 1
    else
      logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "gNB stopped correctly"
      ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
      echo 0
    fi

  else
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "Received command to stop gNB, but there was no instance running"
    ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
    echo 0
  fi

fi
