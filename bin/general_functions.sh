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
exec 2> >(ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "cat >> ${ERROR_LOG_FILE}")
#exec 2> >(ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "printf \"\n$(date +'%Y-%m-%d %H:%M:%S') - $(basename $0) - Error: \" >> ${ERROR_LOG_FILE}; cat >> ${ERROR_LOG_FILE}; printf \"\n\"")

# LOG SEVERITY
SUCCESS='\033[0;32m'
WARNING='\033[0;33m'
ERROR='\033[0;31m'
FATAL='\033[0;88m'
DEBUG_C='\033[0;90m'
NC='\033[0m' # No Color

#############################################################################################
# Generate logs in a specifically structured format
#
# Globals:
#   SHARP_ORCHESTRATOR_USERNAME 
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   DEBUG
#   LOG_FILE
# Arguments:
#   severity: Severity of registered event (info, debug, warning, error or fatal)
#   component: Component generating the event (orchestrator, NRCORE or gNB)
#   ip_address: IP of component generating the event
#   output_text: Test message to show on the log
#   stack_trace: Error trace to show specifically for error logs
# Outputs:
#   Writes complete log message to the file specified by LOG_FILE 
#
#############################################################################################

function logging {

  local severity=$1
  local component=$2
  local ip_address=$3
  local output_text=$4
  local stack_trace=$5
  local file_name=$( basename $0 )

  if [[ "${component}" == "GNB " ]]; then
    case $severity in
      "INFO") ssh -n ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "printf \"$(date +'%Y-%m-%d %H:%M:%S') [INFO ] [${component}] [${ip_address}] - ${output_text} \n\" >> ${LOG_FILE}" & ;;
      "WARNING") ssh -n ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "printf \"${WARNING}$(date +'%Y-%m-%d %H:%M:%S') [WARN ] [${component}] [${ip_address}] [${file_name}] - ${output_text}${NC}\n\" >> ${LOG_FILE}" & ;;
      "ERROR") ssh -n ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "printf \"${ERROR}$(date +'%Y-%m-%d %H:%M:%S') [ERROR] [${component}] [${ip_address}] [${file_name}] - ${output_text}${NC}\n\" >> ${LOG_FILE}" & ;;
      "FATAL") ssh -n ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "printf \"${FATAL}$(date +'%Y-%m-%d %H:%M:%S') [FATAL] [${component}] [${ip_address}] [${file_name}] - ${output_text}${NC}\n\" >> ${LOG_FILE}" & ;;
      "DEBUG") 
        if [[ "${DEBUG}" == "true" ]]; then 
          ssh -n ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "printf \"${DEBUG_C}$(date +'%Y-%m-%d %H:%M:%S') [DEBUG] [${component}] [${ip_address}] - ${output_text}${NC}\n\" >> ${LOG_FILE}" &
        fi
      ;;
    esac

  else
    case $severity in 
      "INFO") printf "$(date +'%Y-%m-%d %H:%M:%S') [INFO ] [${component}] [${ip_address}] - ${output_text} \n" >> ${LOG_FILE} ;; 
      "WARNING") printf "${WARNING}$(date +'%Y-%m-%d %H:%M:%S') [WARN ] [${component}] [${ip_address}] [${file_name}] - ${output_text}${NC}\n" >> ${LOG_FILE} ;;
      "ERROR") printf "${ERROR}$(date +'%Y-%m-%d %H:%M:%S') [ERROR] [${component}] [${ip_address}] [${file_name}] - ${output_text}${NC}\n" >> ${LOG_FILE} ;;
      "FATAL") printf "${FATAL}$(date +'%Y-%m-%d %H:%M:%S') [FATAL] [${component}] [${ip_address}] [${file_name}] - ${output_text}${NC}\n" >> ${LOG_FILE} ;;
      "DEBUG") 
        if [[ "${DEBUG}" == "true" ]]; then 
          printf "${DEBUG_C}$(date +'%Y-%m-%d %H:%M:%S') [DEBUG] [${component}] [${ip_address}] - ${output_text}${NC}\n" >> ${LOG_FILE}
        fi
        ;;
    esac
  fi
}

#############################################################################################
# Check that an UHD device is connected to the machine running the gNB node
#
# Globals:
#   GNB_WORKING_DIR
#   GNB_IP_ADDRESS
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   SHARP_ORCHESTRATOR_IP_USERNAME 
# Arguments:
#   None
# Outputs:
#   1 if uhd device canot be detected, 0 otherwise
#
#############################################################################################

function check_uhd_device {

  UHD_IMAGES_DIR=/usr/share/uhd/images/ uhd_find_devices > ${GNB_WORKING_DIR}/tmp/uhd_find_devices.log 2>&1
  usrp_found=$( grep 'No UHD Devices Found' ${GNB_WORKING_DIR}/tmp/uhd_find_devices.log | wc -l )
  if [[ ${usrp_found} -eq 0 ]]; then  
    logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "USRP Detected in gNB node"
  else
    logging "ERROR" "GNB " "${GNB_IP_ADDRESS}" "No USRP Device in gNB node, please connect a USRP Device"
    ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
    exit 1
  fi

  UHD_IMAGES_DIR=/usr/share/uhd/images/ uhd_usrp_probe > ${GNB_WORKING_DIR}/tmp/uhd_usrp_probe.log 2>&1
  usrp_found=$( grep 'Empty Device Address' ${GNB_WORKING_DIR}/tmp/uhd_usrp_probe.log | wc -l )
  if [[ ${usrp_found} -eq 0 ]]; then 
    logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "USRP probe succesfull in gNB node"
  else
    logging "ERROR" "GNB " "${GNB_IP_ADDRESS}" "Error in USRP probe in gNB node, please verify an USRP Device is connected"
    ssh ${SHARP_ORCHESTRATOR_USERNAME}@${SHARP_ORCHESTRATOR_IP_ADDRESS} "echo \"STOPPED\" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt "
    exit 1
  fi
}

#############################################################################################
# Kills all proccesses associated to a given string
#
# Globals:
#   None
# Arguments:
#   process: String that identifies the process/es to kill
# Outputs:
#   Number of processes associated to a given string that continue running after kill command was executed
#
#############################################################################################

function stop_process {
 local process=$1

 while read -r pid; do
   sudo kill -9 ${pid} > /dev/null 2>&1
 done < <(ps -ef | grep -v "grep" | grep "${process}" | awk {'print $2'})
 
 is_process_still_running=$(ps -ef | grep -v "grep" | grep -c "${process}")
 echo ${is_process_still_running} 
}
