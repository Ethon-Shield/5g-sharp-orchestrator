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
source ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/general_functions.sh

logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to stop 5G - SA network"
echo "STOPPING" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt

# We assume the network will undeploy correctly
is_network_undeployed=1

################ KILL Node manager monitor #################

is_node_manager_stopped=$(stop_process "node_manager_monitor.sh")
if [[ ${is_node_manager_stopped} -gt 0 ]]; then
  logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping node_manager_monitor"
  is_network_undeployed=0
else
    logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "node_manager_monitor killed"	
fi

############ STOP gNB ########################3

# We need to stop the following binaries:
# start_gnb.sh
# gnb_watchdog.sh
# Then we call stop_gnb.sh
# And stop the capture

if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then
  
  is_start_gnb_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "source ${GNB_WORKING_DIR}/bin/general_functions.sh; stop_process \"start_gnb.sh\"")
  if [[ ${gnb_watchdog_stopped} -gt 0 ]]; then
    logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping start gnb"
    is_network_undeployed=0
  else
    logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "start_gnb.sh killed"
  fi


  is_gnb_watchdog_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "source ${GNB_WORKING_DIR}/bin/general_functions.sh; stop_process \"gnb_watchdog.sh\"")
  if [[ ${is_gnb_watchdog_stopped} -gt 0 ]]; then
    logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB watchdog"
    is_network_undeployed=0
  else
    logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB watchdog killed"
  fi
  
  stopping_gnb=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/stop_gnb.sh")
  
  if [[ ${stopping_gnb} -eq 0 ]]; then
    logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "GNB stopped correctly"
  else
    logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB instance"
    is_network_undeployed=0
  fi
  
  is_gnb_capture_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "source ${GNB_WORKING_DIR}/bin/general_functions.sh; stop_process \"${GNB_WORKING_DIR}/tmp/gnb.pcap\"")
  if [[ ${is_gnb_capture_stopped} -gt 0 ]]; then
    logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB pcap capture"
    is_network_undeployed=0
  else
    logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB pcap capture killed"
  fi


fi

############### STOP CORE ##########################
# We need to stop the following binaries:
# start_core.sh
# core_watchdog.sh
# Then we call stop_core.sh
# and stop the pcap capture

is_start_core_stopped=$(stop_process "start_core.sh")
if [[ ${is_start_core_stopped} -gt 0 ]]; then
  logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping start_core script"
  is_network_undeployed=0
else
    logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "start_core.sh killed"
fi

is_core_watchdog_stopped=$(stop_process "core_watchdog.sh")
if [[ ${is_core_watchdog_stopped} -gt 0 ]]; then
  logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping NRCORE watchdog"
  is_network_undeployed=0
else
    logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "NRCORE watchdog killed"
fi

${NRCORE_WORKING_DIR}/bin/stop_core.sh >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log 2>&1 &
sleep 5

is_core_undeployed=1

if [[ "${NRCORE_TECH}" == "OAI" ]]; then

 logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Undeploying OAI NRCORE instance. It might take some time..."
 maxloop=0
 docker_containers_to_check=""
 while read -r image; do
  docker_containers_to_check="${docker_containers_to_check} ${image}"
 done < <(grep "image:" ${NRCORE_DOCKER_COMPOSE_WD}/docker-compose-basic-nrf.yaml | awk '{print $2}')

 is_core_down=0
 until [[ ${is_core_down} -eq 1 ]]; do

   # We assume the core is down
   is_core_down=1

   for container in ${docker_containers_to_check}; do
     is_container_running=$(docker ps -a | grep -c "${container}")
     has_container_exited=$(docker ps -a | grep "${container}" | grep -c "Exited")
     # If one container is running and it has not exited, the core is NOT down 
     if [[ "${is_container_running}" -eq 1 ]]; then
       if ! [[ "${has_container_exited}" -eq 1 ]]; then
          is_core_down=0
       fi
     fi
   done
   sleep 2

   (( maxloop+=1 ))
   if [[ ${maxloop} -ge 40 ]]; then
     logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem while undeploying OAI NRCORE containers"
     break
   fi

 done

 if [[ "${is_core_down}" -eq 1 ]];then
   logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "OAI NRCORE instance undeployed successfully"
 else
   logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "OAI NRCORE could not be undeployed successfully. Run 'docker container ls' to get more info"
   is_network_undeployed=0
 fi

else

  are_open5gs_processes_running=$(ps aux | grep -v "vim" | grep -v "grep" | grep -c "open5gs")
  if [[ "${are_open5gs_processes_running}" -eq 0 ]]; then
    logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Open5gs NRCORE instance undeployed successfully"
  else
    logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Open5gs NRCORE instance could not be undeployed successfully"
    is_network_undeployed=0
  fi
fi

core_capture_stopped=$(stop_process "${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/nrcore_network.pcap")
if [[ ${core_capture_stopped} -gt 0 ]]; then
  logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping NRCORE pcap capture"
  is_network_undeployed=0
else
  logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "NRCORE pcap capture killed"
fi

if [[ ${is_network_undeployed} -eq 1 ]]; then
	logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "5G - SA network was undeployed correctly"
else
	logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem undeploying 5G - SA network. Review logs for more information"
fi

logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Creating backup directory."
${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/make_backup.sh > /dev/null 2>&1 

if [[ $? -eq 1 ]]; then
	logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Error creating creating backup directory"
	echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
	exit 1
fi

rm -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/*
#rm -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/*
> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initial_conf.log
> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/watchdog.log
> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log

echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
sleep 4

