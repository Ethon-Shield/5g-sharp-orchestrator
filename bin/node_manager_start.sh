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

echo "STARTING" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt

logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Starting 5G SA network."
logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Core technology selected = ${NRCORE_TECH}; GNB technology selected = ${GNB_TECH}"

############# CREATE NECESSARY FILES AND UPDATE PERMISSIONS ##############

# Create /tmp files
touch ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/core_status.txt
touch ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/gnb_status.txt
touch ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/param_update_on_realtime.txt
chown -R ${SHARP_ORCHESTRATOR_USERNAME}:${SHARP_ORCHESTRATOR_USERNAME} ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp

# Create necessary log files
[[ -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initial_conf.log ]] || touch ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initial_conf.log
[[ -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/watchdog.log ]] || touch ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/watchdog.log
[[ -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log ]] || touch ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log
chown -R ${SHARP_ORCHESTRATOR_USERNAME}:${SHARP_ORCHESTRATOR_USERNAME} ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs

chmod a+w ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/
chmod a+w ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/

############### CHECK IF BINARIES ARE RUNNING ##############

# Check if gNB instance is running
if [[ ${DEPLOY_NRCORE_ONLY} == "false" ]]; then

  if [[ "${GNB_TECH}" == "OAI" ]]; then

    check_gnb=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "ps -ef | grep \"${NR_SOFTMODEM_BIN} -O ${GNB_CONFIG_FILE}\" | grep -v \"grep\" | wc -l")
    if [[ ${check_gnb} -gt 0 ]];then 
      logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB was already RUNNING, stopping node..."
      gnb_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/stop_gnb.sh")
      if [[ ${gnb_stopped} -eq 0 ]];then
	      logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB stopped correctly. Continuing with process ..."
      else
	      logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB instance. Aborting initialization process ..."
	      exit 1
      fi
    fi

  else

    check_gnb=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "ps -ef | grep \"${SRS_GNB_BIN} -c ${GNB_CONFIG_FILE}\" | grep -v \"grep\" | wc -l")
    if [[ ${check_gnb} -gt 0 ]];then
      logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "An instance of a gNB was already running. Trying to stop it ..."
      gnb_stopped=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/stop_gnb.sh")
      if [[ ${gnb_stopped} -eq 0 ]];then
              logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB instance stopped correctly. Continuing with the process."
      else
              logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping gNB instance. Aborting the process."
              echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
	      exit 1
      fi
    fi

  fi
fi

# Check CORE instance is running
if [[ "${NRCORE_TECH}" == "OAI" ]]; then

  while read -r image; do
    docker_containers_to_check="${docker_containers_to_check} ${image}"
  done < <(grep "image:" ${NRCORE_DOCKER_COMPOSE_WD}/docker-compose-basic-nrf.yaml | awk '{print $2}')

  # We assume its down
  is_core_down=1
  is_core_running=0

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

   if [[ ${is_core_down} -eq 0 ]]; then
     is_core_running=1
   fi

else
   is_core_running=$(ps aux | grep -v "grep" | grep -v "vim" | grep -c open5gs)
fi

if [[ ${is_core_running} -ge 1 ]]; then
  logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "An instance of NRCORE was already running. Trying to stop it ..."
  ${NRCORE_WORKING_DIR}/bin/stop_core.sh >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log 2>&1 &
  sleep 1
  
  #Verify if core has stopped correctly before continuing
  if [[ "${NRCORE_TECH}" == "OAI" ]]; then
     until [[ ${is_core_down} -eq 1 ]]; do
       # We assume the core is down
       is_core_down=1
 
       for container in ${docker_containers_to_check}; do
         is_container_running=$(docker ps -a | grep -c "${container}")
         has_container_exited=$(docker ps -a | grep "${container}" | grep -c "Exited")
         
	 if [[ "${is_container_running}" -eq 1 ]]; then
           if ! [[ "${has_container_exited}" -eq 1 ]]; then
             is_core_down=0
           fi
         fi
       done
    
    sleep 1
 
    (( maxloop+=1 ))
    if [[ ${maxloop} -ge 40 ]]; then
      logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping NRCORE instance. Aborting the process"
      echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
      exit 1
    fi
 
    done
  
  else
     sleep 1
     are_open5gs_processes_running=$(ps aux | grep -v "vim" | grep -v "grep" | grep -c "open5gs")
     if [[ "${are_open5gs_processes_running}" -ge 1 ]]; then
       logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem stopping NRCORE instance. Aborting the process"
       echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
       exit 1	
     fi

  fi
  logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "NRCORE instance stopped correctly. Continuing with the process."

fi

############# CONFIGURE gNB ###############################

if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then

  logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Configuring gNB..."

  ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/configure_gnb.sh"  
  
  if [[ $? -eq 1 ]]; then 
    logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Error while configuring gNB. Check previous messages"
    echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
    exit 1
  else
    logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "gNB configured successfully"
  fi
fi


############# CONFIGURE NRCORE ###############################

logging "DEBUG" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Configuring NRCORE..."

${NRCORE_WORKING_DIR}/bin/configure_core.sh

if [[ $? -eq 1 ]]; then 
  logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Error while configuring NRCORE. Check previous messages"
  echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
  exit 1
else
  logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "NRCORE configured successfully"
fi


############## START NRCORE ##############################

${NRCORE_WORKING_DIR}/bin/start_core.sh >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log 2>&1 &

# If technology is OAI, retrieve logs from all containers
if [[ "${NRCORE_TECH}" == "OAI" ]]; then

  # For this we need to know first if the docker compose has been executed and then we can obtain the logs of all containers

  docker_compose_up_called=$(ps -ef | grep "docker-compose" | grep -c "up -d")
  maxloop=0
  until [[ ${docker_compose_up_called} -ge 1 ]]; do
    sleep 1
    docker_compose_up_called=$(ps -ef | grep "docker-compose" | grep -c "up -d")
    (( maxloop+=1 ))

    if [[ ${maxloop} -ge 20 ]]; then 
      break
    fi
  done

  ${NRCORE_WORKING_DIR}/bin/docker_compose_logs.sh &

fi

###### CHECK FOR SUCCESFUL NRCORE DEPLOYMENT ###############

logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Checking that NRCORE instance has been deployed succesfully"

#Check if core has been deployed succesfully
if [[ "${NRCORE_TECH}" == "OAI" ]]; then

  maxloop=0
  docker_containers_to_check=""
  while read -r image; do
    docker_containers_to_check="${docker_containers_to_check} ${image}"
  done < <(grep "image:" ${NRCORE_DOCKER_COMPOSE_WD}/docker-compose-basic-nrf.yaml | awk '{print $2}')

  until [[ ${core_started} -eq 1 ]]; do
    core_started=1
    nop=1

    for container in ${docker_containers_to_check}; do
      starting_status=$(docker ps -a | grep "${container}" | grep -c "starting")
      unhealth_status=$(docker ps -a | grep "${container}" | grep -c "unhealthy")
      health_status=$(docker ps -a | grep "${container}" | grep -c "healthy")

      if [[ "${starting_status}" -eq 1 ]]; then
        core_started=0
      else
        if [[ "${unhealth_status}" -eq 1 ]]; then
          core_started=0
          container_name=$(docker ps -a | grep "${container}" | awk '{print $NF}')
          logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Detected unhealthy container = ${container_name}"
          logging "WARNING" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Stopping and deploying ${container_name} again"

          docker stop "${container_name}" > /dev/null 2>&1 
          sleep 1
          docker start "${container_name}" > /dev/null 2>&1 &
          sleep 5
          maxloop=0

        else
          if [[ "${health_status}" -eq 1 ]]; then
            nop=1
          else
            core_started=0
          fi
        fi
      fi

    done

    sleep 1

    (( maxloop+=1 ))
    if [[ ${maxloop} -ge 40 ]]; then
      logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "OAI NRCORE deployment took longer than expected. Aborting network initialization process"
      ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_stop.sh &
      exit 1
    fi

  done

else

  maxloop=0
  nrcore_configured_and_healthy=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log 2>/dev/null | grep -c "UDR active")
  until [[ ${nrcore_configured_and_healthy} -eq 1 ]]; do
    sleep 1
    nrcore_configured_and_healthy=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/start_stop_core.log | grep -c "UDR active")

    (( maxloop+=1 ))
    if [[ ${maxloop} -ge 50 ]]; then
      logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Some problem while deploying Open5gs core functions - check start_stop_core.log for more information. Aborting network initialization process"
      ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_stop.sh &
      exit 1
    fi
  done	
fi

logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "NRCORE instance has been deployed succesfully"
${NRCORE_WORKING_DIR}/bin/core_watchdog.sh &

############ GNB DEPLOYMENT #########################

if [[ "${DEPLOY_NRCORE_ONLY}" == "false" ]]; then

  ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/check_connection_with_management_node.sh" > /dev/null
  if [[ $? -eq 1 ]]; then
    logging "INFO" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Error checking connection between gNB and management node. Aborting network initialization process"	  
    ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_stop.sh &
    exit 1
  fi

  # Start gNB 
  check_gnb=$(ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "${GNB_WORKING_DIR}/bin/start_gnb.sh")

  
  if [[ ${check_gnb} -eq 1 ]];then
    logging "ERROR" "NMAN" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Aborting network initialization process"
    ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_stop.sh &
    exit 1
  else
    ssh ${GNB_USERNAME}@${GNB_IP_ADDRESS} "nohup ${GNB_WORKING_DIR}/bin/gnb_watchdog.sh" &
  fi

fi

${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_monitor.sh &

echo "RUNNING" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
