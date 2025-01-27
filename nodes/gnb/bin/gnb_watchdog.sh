#!/bin/bash
#######################################################################
#
#   Author:     ETHON SHIELD SL
#   Version:    0.0.2
#   License:    AGPLv3
#   Copyright:  Copyright (C) 2021-2025, 5G Sharp Orchestrator
#   Email:      sharp-orchestrator@ethonshield.com
#
#######################################################################

source ${HOME}/sharp-orchestrator.src
source ${GNB_WORKING_DIR}/bin/general_functions.sh

logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "gNB WATCHDOG called"

######################################################
# Check if gNB binary is active 
#
# Globals:
#   GNB_IP_ADDRESS
#   GNB_TECH
#   NR_SOFTMODEM_BIN
#   GNB_CONFIG_FILE
#   GNB_IP_WORKING_DIR
#   SRS_GNB_BIN
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   SHARP_ORCHESTRATOR_USERNAME
# Arguments:
#   None
# Outputs:
#   Generate logs that are written to main log file
#   Writes gNB status value to text file
######################################################

function check_status_gnb {
  logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "Checking status of gNB"

  if [[ "${GNB_TECH}" == "OAI" ]]; then
    check_gnb=$(ps -ef | grep "${NR_SOFTMODEM_BIN} -O ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)
    gnb_lib_uhd=$(grep -c "library liboai_device.so is not loaded: libuhd.so" ${GNB_WORKING_DIR}/logs/gnb.log)
    if [[ ${gnb_lib_uhd} -ge 1 ]]; then
      logging "ERROR" "GNB " "${GNB_IP_ADDRESS}" "Check version of UHD installed"
    fi
  else
    check_gnb=$(ps -ef | grep "${SRS_GNB_BIN} -c ${GNB_CONFIG_FILE}" | grep -v "grep" | wc -l)	  
    unstable_gnb=$(grep -c "LIBUSB_TRANSFER_NO_DEVICE" "${GNB_WORKING_DIR}/logs/gnb.log")

    if [[ "${unstable_gnb}" -ge 100 ]]; then
      ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"UNSTABLE\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
    fi
  fi

  if [[ ${check_gnb} -eq 0 ]]; then
    ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
  fi

}

######################################################
# Check if gNB binary is healthy
#
# Globals:
#   GNB_IP_ADDRESS
#   GNB_IP_WORKING_DIR	
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   SHARP_ORCHESTRATOR_USERNAME
# Arguments:
#   None
# Outputs:
#   Generate logs that are written to main log file
#   Writes gNB status value to text file
######################################################

function check_gnb_stability {

  > ${GNB_WORKING_DIR}/logs/gnb_analysis.log  
  cp ${GNB_WORKING_DIR}/logs/gnb.log ${GNB_WORKING_DIR}/logs/gnb_analysis.log > /dev/null
  > ${GNB_WORKING_DIR}/logs/gnb.log
  cat ${GNB_WORKING_DIR}/logs/gnb_analysis.log >> ${GNB_WORKING_DIR}/logs/gnb_complete.log

  gnb_stability=$(grep -a -e "aborting RX processing" -e "problem receiving samples" ${GNB_WORKING_DIR}/logs/gnb_analysis.log | wc -l)

  if [[ ${gnb_stability} -gt 100 ]]; then
    logging "WARNING" "GNB " "${GNB_IP_ADDRESS}" "gNB is unstable"
    ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"UNSTABLE\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
  fi
}

check_stability_cnt=0
while true; do 

  check_status_gnb

  if [[ ${check_stability_cnt} -eq 10 && "${GNB_TECH}" == "OAI" ]]; then
    check_gnb_stability
    check_stability_cnt=0
  fi
  (( check_stability_cnt+=1 ))
  sleep 2

done
