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
source ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh

logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Node Manager Supervisor started"
 
##################################################################################
# Monitor the value of NRCORE status variable and restart the services if necessary
#
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   NRCORE_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   None
##################################################################################

function monitor_core {
# Get status of the core 
  inbox_core=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/core_status.txt)
  
  logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "CORE Status: ${inbox_core}"
  case ${inbox_core} in
    "UNHEALTHY") 
      binary_running=$(ps -ef | grep -v "grep" | grep -v "vim" | grep restart_unhealthy_containers.sh | wc -l)
      if [[ "${binary_running}" -eq 0 ]]; then
        ${NRCORE_WORKING_DIR}/bin/restart_unhealthy_containers.sh &
      fi
     ;;
  esac
}

##################################################################################
# Monitor the value of gNB status variable and restart the service if necessary
#
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   GNB_USERNAME
#   GNB_IP_ADDRESS
#   GNB_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   Generate logs that are written to main log file
##################################################################################

function monitor_gnb {
  # Get status of the gnb
  inbox_gnb=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt)
  
  logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "GNB Status: ${inbox_gnb}"
  case ${inbox_gnb} in
    "RUNNING")
      is_watchdog_active=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "ps -ef | grep -v \"grep\" | grep -c \"${GNB_WORKING_DIR}/bin/gnb_watchdog.sh\"")
      if [[ ${is_watchdog_active} -eq 0 ]]; then
        ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "nohup ${GNB_WORKING_DIR}/bin/gnb_watchdog.sh" &
      fi 
      ;;
    "STARTING")
      logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "GNB instance is starting..."
      ;;
    "STOPPING")
      logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "GNB instance is stopping..."
      ;;
    "STOPPED")    
      logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Detected gNB is down"
      gnb_watchdog_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "source ${GNB_WORKING_DIR}/bin/general_functions.sh; stop_process \"gnb_watchdog.sh\"")
      if [[ ${gnb_watchdog_stopped} -gt 0 ]]; then
        logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB watchdog"
      else
        logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "GNB watchdog killed"
      fi
      ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/start_gnb.sh" &
     ;;
    "UNSTABLE")
      logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Detected gNB is unstable. Stopping instance"
      gnb_watchdog_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "source ${GNB_WORKING_DIR}/bin/general_functions.sh; stop_process \"gnb_watchdog.sh\"")
      if [[ ${gnb_watchdog_stopped} -gt 0 ]]; then
	logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB watchdog"
      else
	logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB watchdog killed"
      fi
      ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/stop_gnb.sh"
     ;;
  esac

}

##################################################################################
# Get the string to search for before updating the corresponding parameter
#
# Globals:
#   GNB_TECH
# Arguments:
#   param: paramter key to update
# Outputs:
#   string for the sed to search before updating the value to STDOUT
##################################################################################

function sed_update_parameter_string {
  local param=$1

  case $param in
    "ARFCN") 
      if [[ "${GNB_TECH}" == "OAI" ]]; then 
        echo "absoluteFrequencySSB"
      else
        echo "dl_arfcn"
      fi
      ;;
    "POINT_A") echo "PointA";;
    "BAND") 
      if [[ "${GNB_TECH}" == "OAI" ]]; then 
        echo "dl_frequencyBand"
      else
        echo "Band"
      fi
      ;;
    "CHANNEL_BW") echo "channel_bandwidth";;
    "SCS") echo "common_scs";;
  esac

}

##################################################################################
# Monitor the value of paramater update variable and replace variables if necessary
#
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   SHARP_ORCHESTRATOR_IP_ADDRESS
#   DEPLOY_NRCORE_ONLY
#   GNB_USERNAME
#   GNB_IP_ADDRESS
#   GNB_CONFIG_FILE
#   GNB_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   Generate logs that are written to main log file 
##################################################################################

function monitor_real_time_parameter_update {
  update=false

  if [[ -s "${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/param_update_on_realtime.txt" && "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then
    while read line; do
      # Get parameter update on realtime inbox 
      inbox_param_update_on_realtime_key=$(echo "${line}" | cut -d ":" -f1)
      inbox_param_update_on_realtime_val=$(echo "${line}" | cut -d ":" -f2)

      logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Parameter update detected - ${inbox_param_update_on_realtime_key}:${inbox_param_update_on_realtime_val}"
      if ! [[ -z "${inbox_param_update_on_realtime_key}" && -z "${inbox_param_update_on_realtime_val}" ]]; then
        # Ensure the parameter is between the possible options
        if [[ -v VALID_PARAMS[${inbox_param_update_on_realtime_key}] ]]; then

          # Update value in config file
          previous_val=${VALID_PARAMS[${inbox_param_update_on_realtime_key}]}
          logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Updating gNB values - ${inbox_param_update_on_realtime_key}:${inbox_param_update_on_realtime_val}"
          string_to_sed=$(sed_update_parameter_string ${inbox_param_update_on_realtime_key})
          ssh -n ${GNB_USERNAME}@${GNB_IP_ADDRESS} "sed -i '/${string_to_sed}/s/${previous_val}/${inbox_param_update_on_realtime_val}/' ${GNB_CONFIG_FILE}" > /dev/null 
          # Update new current value in array 
          VALID_PARAMS["${inbox_param_update_on_realtime_key}"]="${inbox_param_update_on_realtime_val}"
          
	  update=true
        else
          logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Parameter update detected - ${inbox_param_update_on_realtime_key} not within the options"
        fi

      else
        logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Parameter update detected - missing key or value"
      fi

    done < <(cat "${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/param_update_on_realtime.txt" | tr ";" "\n")

    # Empty file
    > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/param_update_on_realtime.txt
    
    if [[ "${update}" == "true" ]]; then  
     gnb_watchdog_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "source ${GNB_WORKING_DIR}/bin/general_functions.sh; stop_process \"gnb_watchdog.sh\"")
     if [[ ${gnb_watchdog_stopped} -gt 0 ]]; then
       logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB watchdog"
     else
       logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB watchdog killed"
     fi

     inbox_gnb=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt)
     if [[ "${inbox_gnb}" == "STARTING" ]]; then
        ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "source ${GNB_WORKING_DIR}/bin/general_functions.sh; stop_process \"start_gnb.sh\"" > /dev/null
     fi
     ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/stop_gnb.sh" > /dev/null
    fi
  fi

}

while true; do

  monitor_core 
  [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]] && monitor_gnb
  monitor_real_time_parameter_update

  sleep 5

done
