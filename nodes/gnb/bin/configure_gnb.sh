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

[[ -d ${GNB_WORKING_DIR}/tmp/ ]] && rm -f ${GNB_WORKING_DIR}/tmp/*

if [[ "${NRCORE_TECH}" == "OAI" ]];then
	# IP ROUTING 
	shared_ip=$([[ ${GNB_IP_ADDRESS} == ${NRCORE_IP_ADDRESS} ]] && echo '1' || echo '0')
	if [[ ${shared_ip} -eq 0 ]]; then
		
		logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "Configuring IP route between NRCORE and gNB nodes"
		core_subnet=${NRCORE_NETWORK}

		check_ip_route_rule=$(ip route | grep -c "${core_subnet}")
		if [[ ${check_ip_route_rule} -ge 1 ]]; then
			sudo ip route del ${core_subnet}
		fi

		gnb_interface=$( ifconfig | grep -B 1 ${GNB_IP_ADDRESS} | head -n 1 | awk '{print $1;}' | cut -d ':' -f1 )

		sudo ip route add ${core_subnet} via ${NRCORE_IP_ADDRESS} dev ${gnb_interface}

		check_ip_routing=$(ip route |  grep "${core_subnet} via ${NRCORE_IP_ADDRESS} dev ${gnb_interface}" | wc -l )

		if [[ ${check_ip_routing} -eq 0 ]]; then 
			logging "ERROR" "GNB " "${GNB_IP_ADDRESS}" "Error configuring IP route between NRCORE and gNB nodes - Please check sudo permissions"
			exit 1
		else
			logging "DEBUG" "GNB " "${GNB_IP_ADDRESS}" "gNB IP Routing configured correctly"
		fi 

	fi

fi

## Check connection with SDR
check_uhd_device 
