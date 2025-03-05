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

logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "NRCORE watchdog called"

check_status=0

######################################################
# Check if all NRCORE services are active and healthy
#
# Globals:
#   NRCORE_TECH
#   NRCORE_DOCKER_COMPOSE_WD
#   NRCORE_IP_ADDRESS
#   NR_BIN_INDEX
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   Generate logs that are written to main log file
#   Writes NRCORE status value to text file
######################################################

function check_status_core {
	status_core=1
	nop=1
	
	if [[ "${NRCORE_TECH}" == "OAI" ]]; then

		docker_containers_to_check=""
		while read -r image; do
  		 docker_containers_to_check="${docker_containers_to_check} ${image}"
		done < <(grep "image:" ${NRCORE_DOCKER_COMPOSE_WD}/docker-compose-basic-nrf.yaml | awk '{print $2}')

		for container in ${docker_containers_to_check}; do
        		container_id=$(docker ps -a | grep "${container}" | awk '{print $1}')
			unhealthy_status=$(docker container inspect -f '{{.State.Health}}' ${container_id} | grep unhealthy | wc -l)
			if [[ "${unhealthy_status}" -eq 0 ]]; then 
				starting_status=$(docker container inspect -f '{{.State.Health}}' ${container_id} | grep starting | wc -l)
				if [[ "${starting_status}" -eq 0 ]]; then
					logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Docker container ${container} is running"	
					nop=1
				else
					logging "WARNING" "CORE" "${NRCORE_IP_ADDRESS}" "Docker container ${container} is starting"
				fi
			elif [[ "${unhealthy_status}" -gt 0 ]]; then 
				logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Docker container ${container} is unhealthy"
				(( status_core*=0 ))	
			else
				logging "WARNING" "CORE" "${NRCORE_IP_ADDRESS}" "Unkown container ${container}"
			fi
		done
	
	else
		
		for binary in "${NR_BIN_INDEX[@]}"; do
			binary_status=$(ps aux |grep -v "grep" | grep -c "/install/bin/${binary}")
			if [[ "${binary_status}" -eq 1 ]]; then
				logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Service ${binary} is running"
				nop=1				
			elif [[ "${binary_status}" -gt 1 ]]; then
				logging "WARNING" "CORE" "${NRCORE_IP_ADDRESS}" "Service ${binary} has more than one instance running"
			else
				logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Detected ${binary} service is not running"
				(( status_core*=0 ))
			fi
	        done

	fi

	if [[ ${status_core} -eq 1 ]]; then
          echo "HEALTHY" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/core_status.txt
        else
	  echo "UNHEALTHY" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/core_status.txt	
	fi
  }

while true; do 

  check_status_core
  sleep 2

done
