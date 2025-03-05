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
source ${GNB_WORKING_DIR}/bin/general_functions.sh

######################################################
# Check if gNB instance have been deployed correctly
#
# Globals:
#   GNB_TECH
#   GNB_WORKING_DIR
#   GNB_IP_ADDRESS
#   SHARP_ORCHESTRATOR_USERNAME
#   SHARP_ORCHESTRATOR_IP_ADDRESS
# Arguments:
#   None
# Outputs:
#   1 if there was a problem deploying gNB instance, 0 otherwise
######################################################

function check_gnb_correct_deployment {

  max_time=30
  time=0
  is_gnb_started=0
  until [[ ${is_gnb_started} -ge 1 ]]; do
    if [[ "${GNB_TECH}" == "OAI" ]]; then
      [[ -f ${GNB_WORKING_DIR}/logs/gnb.log ]] && is_gnb_started=$(cat ${GNB_WORKING_DIR}/logs/gnb.log | grep -c "got sync (L1_stats_thread)")
    else
      [[ -f ${GNB_WORKING_DIR}/logs/gnb.log ]] && is_gnb_started=$(cat ${GNB_WORKING_DIR}/logs/gnb.log | grep -c -e "==== gNB started ===" -e "==== gNodeB started ===")
    fi
    (( time+=1 ))
    sleep 1
    if [[ ${time} -eq ${max_time} ]];then
      logging "ERROR" "GNB " "${GNB_IP_ADDRESS}" "Some problem deploying gNB instance"
      while read -r line; do
        logging "ERROR" "GNB " "${GNB_IP_ADDRESS}" "${line}" 2>/dev/null
      done < <(cat "${GNB_WORKING_DIR}/logs/gnb.log")
      sleep 1
      ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
      exit 1 
    fi

  done
  logging "INFO" "GNB " "${GNB_IP_ADDRESS}" "gNB instance has been deployed succesfully"
  ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"RUNNING\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
  exit 0

}

[[ -f ${GNB_WORKING_DIR}/logs/gnb.log ]] || touch ${GNB_WORKING_DIR}/logs/gnb.log
chmod o=rw ${GNB_WORKING_DIR}/logs/gnb.log

ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STARTING\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "

if [[ ! -f ${GNB_WORKING_DIR}/tmp/gnb.pcap ]]; then
  touch ${GNB_WORKING_DIR}/tmp/gnb.pcap
  chmod o=rw ${GNB_WORKING_DIR}/tmp/gnb.pcap
  tshark -i any -f "sctp" -w ${GNB_WORKING_DIR}/tmp/gnb.pcap > /dev/null 2>&1 &
  logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "Starting gNB packet capture"
fi

logging "INFO" "GNB " "${GNB_IP_ADDRESS}" "Deploying gNB instance"

if [[ "${GNB_TECH}" == "OAI" ]]; then

  check_gnb=$(ps -ef | grep "${NR_SOFTMODEM_BIN} -O ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)
  if [[ ${check_gnb} -gt 0 ]]; then
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "Received command to start gNB but there is an instance already running"
  else
    # Check UHD 
    check_uhd_device

    # Start gNB in background
    UHD_IMAGES_DIR=/usr/share/uhd/images/
    sudo --preserve-env=UHD_IMAGES_DIR unbuffer ${NR_SOFTMODEM_BIN} -O ${GNB_CONFIG_FILE} -E --sa > ${GNB_WORKING_DIR}/logs/gnb.log 2>&1 &
    logging "INFO" "GNB " "${GNB_IP_ADDRESS}" "Checking that gNB instance has been deployed succesfully"
    check_gnb_correct_deployment

  fi

else

  check_gnb=$(ps -ef | grep "${SRS_GNB_BIN} -c ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)
  if [[ ${check_gnb} -gt 0 ]]; then
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "Received command to start gNB but there is an instance already running"
    
    ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"RUNNING\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
  else
    # Check UHD
    check_uhd_device 

    # Start gNB in background
    sudo unbuffer ${SRS_GNB_BIN} -c ${GNB_CONFIG_FILE} > ${GNB_WORKING_DIR}/logs/gnb.log 2>&1 &
    logging "INFO" "GNB " "${GNB_IP_ADDRESS}" "Checking that gNB instance has been deployed succesfully"
    check_gnb_correct_deployment

  fi
fi
