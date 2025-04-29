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
source ${NRCORE_WORKING_DIR}/bin/general_functions.sh


	
if [[ "${NRCORE_TECH}" == "OAI" ]]; then
        
        logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Started process to restart OAI unhealthy containers"
	docker_containers_to_check=""
	while read -r image; do
	 docker_containers_to_check="${docker_containers_to_check} ${image}"
	done < <(grep "image:" ${NRCORE_DOCKER_COMPOSE_WD}/docker-compose-basic-nrf.yaml | awk '{print $2}')

	for container in ${docker_containers_to_check}; do
		container_id=$(docker ps -a | grep "${container}" | awk '{print $1}')
		container_status=$(docker container inspect -f '{{.State.Health}}' ${container_id} | grep unhealthy | wc -l)
		if [[ "${container_status}" -eq 0 ]]; then
			logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Docker container ${container} is running"
			nop=1
		elif [[ "${container_status}" -gt 0 ]]; then
			logging "WARNING" "CORE" "${NRCORE_IP_ADDRESS}" "Detected unhealthy container: ${container}. Restarting it. "
			docker container stop ${container_id} > /dev/null 2>&1
			docker container start ${container_id} &
			sleep 1
		else
			logging "WARNING" "CORE" "${NRCORE_IP_ADDRESS}" "Unkown container ${container}"
		fi
	done

else
        logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Started process to restart Open5gs unhealthy services"
	for binary in "${NR_BIN_INDEX[@]}"; do
		binary_status=$(ps aux |grep -v "grep" | grep -c "/install/bin/${binary}")
		if [[ "${binary_status}" -eq 1 ]]; then
	            logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Service ${binary} is running"
		elif [[ "${binary_status}" -gt 1 ]]; then
		    logging "WARNING" "CORE" "${NRCORE_IP_ADDRESS}" "Service ${binary} has more than one instance running"
		else
		    logging "WARNING" "CORE" "${NRCORE_IP_ADDRESS}" "Detected ${binary} service is not running. Restarting the service."
		    BIN_PATH=${NRCORE_OPEN5GS_WD}/install/bin/${binary}
		    CONF_PATH=${NRCORE_WORKING_DIR}/conf/open5gs/${NR_BIN_CONF[${binary}]}
		    LOG_PATH=${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/${NR_BIN_LOG[${binary}]}
		    echo "" > ${LOG_PATH}

		    if [[ -f ${BIN_PATH} ]]; then
		      if [[ -f ${CONF_PATH} ]]; then
			${BIN_PATH} -c ${CONF_PATH} > /dev/null 2>&1 &
			sleep 1
			node_ini=$(cat ${LOG_PATH} | grep -c "${NR_BIN_NAME[${binary}]} initialize...done")
			if [[ ${node_ini} -eq 1 ]]; then
			  logging "DEBUG" "CORE" "${NRCORE_IP_ADDRESS}" "Succesfully restarted ${binary} service"
			else
			  logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Error starting ${binary} service"
			  exit 1
			fi
		      else
			logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Configuration file not found in ${CONF_PATH}"
			exit 1
		      fi
		    else
		      logging "ERROR" "CORE" "${NRCORE_IP_ADDRESS}" "Binary ${binary} not found in ${BIN_DIR}"
		      exit 1
		    fi
		fi
	done

fi


