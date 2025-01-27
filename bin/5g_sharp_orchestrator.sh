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

# Global variables 

GREEN='\e[32m'
BLUE='\e[34m'
CLEAN='\e[0m'

IMSI=""
KI=""
OPC=""

# Optional argument for script
interactive_mode=false

declare -A NEW_PARAMS
NEW_PARAMS=(
	["ARFCN"]=""
	["POINT_A"]=""
	["BAND"]=""
	["CHANNEL_BW"]=""
	["SCS"]=""

)

############################################################################################# 
# Executes the necessary actions to exit the program correctly
# 
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function clean_exit {

	network_status=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt)
  if [[ "${network_status}" != "STOPPED" && "${network_status}" != "ERROR" ]]; then
    echo -ne "
  If you exit the application, the network will stop. 
  Are you sure you want to exit? (y/n): "
    read choice
    case "$choice" in
      y|Y ) 
        ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_stop.sh
        kill -9 ${loop_pid} > /dev/null 2>/dev/null
        tmux kill-session -t interactive_menu > /dev/null
        exit 0
        ;;
      n|N ) 
        main_menu
        ;;
      * ) 
        clean_exit  
        ;;
    esac
  else
    kill -9 ${loop_pid} > /dev/null 2>/dev/null
    tmux kill-session -t interactive_menu > /dev/null
    exit 0
  fi
}

trap clean_exit SIGINT

############################################################################################# 
# Run the main loop that controls the execution of the different parts of the orchestrator 
# 
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   SHARP_ORCHESTRATOR_IP_ADDRESS
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function orchestrator_loop {
  while true; do

    if [[ -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/orchestrator_cmd.txt ]]; then
      orch_cmd=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/orchestrator_cmd.txt)
      echo "" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/orchestrator_cmd.txt
    fi

    if [[ -f ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt ]]; then
      network_status=$(cat ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt)
    fi

    case "${orch_cmd}" in 
      "START")
        if [[ "${network_status}" == "STARTING" ]]; then
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to start the network, but it is already starting." 
        elif [[ "${network_status}" == "ERROR" ]]; then
          logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "SHARP ORCHESTRATOR EXPERIMENTED UNKNOWN ERROR. PLEASE, CHEACK LOGS AND RESET THE APPLICATION" 
        elif [[ "${network_status}" == "RUNNING" ]]; then
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to start the network, but it is already running." 
        elif [[ "${network_status}" == "STOPPING" ]]; then
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to start the network, but it is currently stopping. Please, wait until it is completeley stopped."
        elif [[ "${network_status}" == "STOPPED" ]]; then
          logging "INFO" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to start the network. Starting network initialization process."	
          ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/check_conf.sh > ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log
          if [[ $? -eq 0 ]]; then
            ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_initialize.sh >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log
            if [[ $? -eq 0 ]]; then
              logging "INFO" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Network initialization completed succesfully. Starting 5G - SA network."
              ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_start.sh &
            else
              logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Network initialization failed. Check ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log for more information"
              echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
            fi
          else
            logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Network initialization failed. Check ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log for more information"
            echo "STOPPED" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
          fi
        fi
        ;;

      "STOP")
        if [[ "${network_status}" == "STARTING" ]]; then
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to stop the network, but it is currently starting. Please, wait until it is completely started."
        elif [[ "${network_status}" == "ERROR" ]]; then
          logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "SHARP ORCHESTRATOR EXPERIMENTED UNKNOWN ERROR. PLEASE, CHEACK LOGS AND RESET THE APPLICATION" 
        elif [[ "${network_status}" == "RUNNING" ]]; then 
          ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_stop.sh &
        elif [[ "${network_status}" == "STOPPING" ]]; then 
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to stop the network, but it is already stopping." 
        elif [[ "${network_status}" == "STOPPED" ]]; then
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Received command to stop the network, but it is already stopped." 
        fi
        ;;
    esac

    sleep 1 
  done
}

############################################################################################# 
# Displays the menu to upodate parameters in real time for OAI gNB technology
# 
# Globals:
#   VALID_PARAMS
#   NEW_PARAMS
#   GREEN
#   BLUE
#   CLEAN
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function update_parameters_banner_oai {

  echo -ne "
  # UPDATE PARAMETER IN REAL TIME #

  Current ARFCN    	 = ${VALID_PARAMS["ARFCN"]}       New ARFCN      = ${NEW_PARAMS["ARFCN"]} 
  Current POINT_A 	 = ${VALID_PARAMS["POINT_A"]}       New POINT_A    = ${NEW_PARAMS["POINT_A"]}

  ${GREEN}1)${CLEAN} Set ARFCN
  ${GREEN}2)${CLEAN} Set POINT_A
  ${GREEN}3)${CLEAN} Update parameters

  ${GREEN}0)${CLEAN} Return

  ${BLUE}Choose an option:${CLEAN} "

}

############################################################################################# 
# Displays the menu to update parameters in real time for SRS gNB technology
# 
# Globals:
#   VALID_PARAMS
#   NEW_PARAMS
#   GREEN
#   BLUE
#   CLEAN
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function update_parameters_banner_srs {

  echo -ne "
  # UPDATE PARAMETER IN REAL TIME #

  Current ARFCN      = ${VALID_PARAMS["ARFCN"]}         New ARFCN       = ${NEW_PARAMS["ARFCN"]} 
  Current BAND 	     = ${VALID_PARAMS["BAND"]}             New BAND 	      = ${NEW_PARAMS["BAND"]}
  Current CHANNEL_BW = ${VALID_PARAMS["CHANNEL_BW"]}             New CHANNEL_BW  = ${NEW_PARAMS["CHANNEL_BW"]}
  Current SCS 	     = ${VALID_PARAMS["SCS"]}             New SCS 	      = ${NEW_PARAMS["SCS"]}
  " 
  echo -ne "

  ${GREEN}1)${CLEAN} Set ARFCN
  ${GREEN}2)${CLEAN} Set BAND
  ${GREEN}3)${CLEAN} Set CHANNEL_BW
  ${GREEN}4)${CLEAN} Set SCS
  ${GREEN}5)${CLEAN} Update parameters

  ${GREEN}0)${CLEAN} Return

  ${BLUE}Choose an option:${CLEAN} "

}

############################################################################################# 
# Displays the menu to edit database information
# 
# Globals:
#   IMSI
#   KI
#   OPC   
#   GREEN
#   BLUE
#   CLEAN
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function edit_database_banner {
  echo -ne "
  # EDIT DATABASE #
  
  IMPORTANT: For the changes to have an effect you need to stop the network first.

  ${GREEN}1)${CLEAN} Set IMSI                           IMSI    =    ${IMSI}
  ${GREEN}2)${CLEAN} Set KI                             KI      =    ${KI}
  ${GREEN}3)${CLEAN} Set OPC                            OPC     =    ${OPC}
  ${GREEN}4)${CLEAN} Add subscriber to database
  ${GREEN}5)${CLEAN} Update subscriber information
  ${GREEN}6)${CLEAN} Remove subscriber from database

  ${GREEN}0)${CLEAN} Return${CLEAN}

  ${BLUE}Choose an option:${CLEAN} " 

}

############################################################################################# 
# Displays main application menu
#
# Globals:
#   GREEN
#   BLUE
#   CLEAN
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function main_menu_banner {
  echo -ne "
  # SHARP ORCHESTRATOR INTERACTIVE MENU #

  ${GREEN}1)${CLEAN} Start Network
  ${GREEN}2)${CLEAN} Stop Network
  ${GREEN}3)${CLEAN} Change Network Parameters
  ${GREEN}4)${CLEAN} Make Backup
  ${GREEN}5)${CLEAN} Edit Database

  ${GREEN}0)${CLEAN} Exit

  ${BLUE}Choose an option:${CLEAN} " 


}

############################################################################################# 
# Runs necessary logic to update parameters in real time
#
# Globals:
#   GNB_TECH
#   VALID_PARAMS
#   NEW_PARAMS
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function update_parameters {
  while true; do
    clear
    if [[ "${GNB_TECH}" == "OAI" ]]; then
      update_parameters_banner_oai
    else
      update_parameters_banner_srs
    fi
    read input 
    if [[ "${GNB_TECH}" == "OAI" ]]; then
      case ${input} in
        1)
          echo -ne "
  New ARFCN: " 	    
          read new_arfcn
          if ! [[ "${new_arfcn}" == *[[:punct:]]* ]]; then
            NEW_PARAMS["ARFCN"]=${new_arfcn}
          else
            logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "No strange characters please"
          fi
          ;;
        2)
          echo -ne "
  New POINT_A: " 	    
          read new_point_a 
          if ! [[ "${new_point_a}" == *[[:punct:]]* ]]; then
            NEW_PARAMS["POINT_A"]=${new_point_a}
          else
            logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "No strange characters please"
          fi
          ;;
        3)
          update_command=""
          for key in ${!NEW_PARAMS[@]}; do
            if ! [[ -z "${NEW_PARAMS[${key}]}" ]]; then
              VALID_PARAMS["${key}"]=${NEW_PARAMS[${key}]}
              update_command="${update_command}${key}:${NEW_PARAMS[${key}]};"
              NEW_PARAMS["${key}"]="" 
            fi  
          done

          if ! [[ -z "${update_command}" ]]; then 
            update_command="${update_command::-1}"
            echo "${update_command}" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/param_update_on_realtime.txt
            sleep 1	      
          fi
          ;;
        0)
          return
          ;;
        *) echo -ne "
  Invalid option." 
          sleep 1;;
      esac
    else
      case ${input} in
        1)
          echo -ne "
  New ARFCN: " 	    
          read new_arfcn
          if ! [[ "${new_arfcn}" == *[[:punct:]]* ]]; then
            NEW_PARAMS["ARFCN"]=${new_arfcn}
          else
            logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "No strange characters please"
          fi
          ;;
        2)
          echo -ne "
  New BAND: "        
          read new_band
          if ! [[ "${new_band}" == *[[:punct:]]* ]]; then
            NEW_PARAMS["BAND"]=${new_band}
          else
            logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "No strange characters please"
          fi
          ;;
        3)
          echo -ne "
  New CHANNEL_BW: "        
          read new_channel_bw
          if ! [[ "${new_channel_bw}" == *[[:punct:]]* ]]; then
            NEW_PARAMS["CHANNEL_BW"]=${new_channel_bw}
          else
            logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "No strange characters please"
          fi
          ;;
        4)
          echo -ne "
  New SCS: "        
          read new_scs
          if ! [[ "${new_scs}" == *[[:punct:]]* ]]; then
            NEW_PARAMS["SCS"]=${new_scs}
          else
            logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "No strange characters please"
          fi
          ;;
        5)
          update_command=""
          for key in ${!NEW_PARAMS[@]}; do
            if ! [[ -z "${NEW_PARAMS[${key}]}" ]]; then
              VALID_PARAMS["${key}"]=${NEW_PARAMS[${key}]}
              update_command="${update_command}${key}:${NEW_PARAMS[${key}]};"
              NEW_PARAMS["${key}"]="" 
            fi  
          done

          if ! [[ -z "${update_command}" ]]; then 
            update_command="${update_command::-1}"
            echo "${update_command}" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/param_update_on_realtime.txt
            sleep 1	      
          fi
          ;;
        0)
          return
          ;;
        *) echo -ne "
  Invalid option." 
          sleep 1;;
      esac
    fi
  done
}

############################################################################################# 
# Runs necessary logic to edit database information 
#
# Globals:
#   IMSI
#   KI
#   OPC 
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   SHARP_ORCHESTRATOR_IP_ADDRESS
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function edit_database {
  while true; do
    clear
    edit_database_banner 

    read input 
    case ${input} in
      1)
        echo -ne "
  IMSI: " 	    
        read IMSI
        clear
        edit_database_banner
        ;;
      2)
        echo -ne "
  KI: "
        read KI
        clear
        edit_database_banner
        ;;
      3)
        echo -ne "
  OPC: "
        read OPC
        clear
        edit_database_banner
        ;;
      4)
        if [[ "${IMSI}" != "" ]] && [[ "${KI}" != "" ]] && [[ ${OPC} != "" ]]; then 
          ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/database_manager.sh -c add -i ${IMSI} -k ${KI} -o ${OPC}
          if [[ $? -eq 0 ]]; then
            IMSI=""
            KI=""
            OPC=""
            edit_database_banner
          fi
        else
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "IMSI, KI and OPC values MUST NOT be null in order to add a subscriber to the database "
        fi
        ;;
      5)
        if [[ "${IMSI}" != "" ]] && [[ "${KI}" != "" ]] && [[ ${OPC} != "" ]]; then
          ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/database_manager.sh -c update -i ${IMSI} -k ${KI} -o ${OPC}
          if [[ $? -eq 0 ]]; then
            IMSI=""
            KI=""
            OPC=""
            edit_database_banner
          fi
        else
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "IMSI, KI and OPC values MUST NOT be null in order to update subscriber information  "
        fi
        ;;
      6) 
        if [[ "${IMSI}" != "" ]]; then
          ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/database_manager.sh -c remove -i ${IMSI} 
          if [[ $? -eq 0 ]]; then
            IMSI=""
            edit_database_banner
          fi
        else
          logging "WARNING" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "IMSI value must not be null in order to remove a subscriber from the database "      
        fi
        ;;
      0)
        return
        ;;
      *) echo -ne "
  Invalid option." 
        sleep 1
        ;;

      esac
    done
  }

############################################################################################# 
# Runs the logic for the main menu of the application
#
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function main_menu {
  clear
  main_menu_banner

  read input 
  case ${input} in
    1) echo "START" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/orchestrator_cmd.txt ;;
    2) echo "STOP" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/orchestrator_cmd.txt ;;
    3) update_parameters ;;
    4)
      echo -ne "
  Making Backup... "
      ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/make_backup.sh > /dev/null    
      ;; 
    5) edit_database ;;
    0) clean_exit ;;
    *) 
      echo -ne "
  Invalid option."
      sleep 1 
      ;;
  esac
}

############################################################################################# 
# Resets the network status to STOPPED
#
# Globals:
#   SHARP_ORCHESTRATOR_WORKING_DIR
#   SHARP_ORCHESTRATOR_IP_ADDRESS
# Arguments:
#   None
# Outputs:
#   None
#
#############################################################################################

function reset_network_status {

  echo "Initializing SHARP ORCHESTRATOR, please wait until \"## SHARP ORCHESTRATOR INITIALIZED ##\" appears in the log file"
  ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/check_conf.sh > ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log
  if [[ $? -eq 0 ]]; then
    ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_initialize.sh >> ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log
    if [[ $? -eq 0 ]]; then
      ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/node_manager_reset.sh &
    else
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Orchestrator initialization failed. Check ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log for more information"
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Reached ERROR state. Please, make necessary corrections and restart the application"
      echo "ERROR" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
    fi
  else
    logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Orchestrator initialization failed. Check ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/initialization.log for more information"
    logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Reached ERROR state. Please, make necessary corrections and restart the application"
    echo "ERROR" > ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/network_status.txt
  fi

}

####################################
### Create necessary directories ###
####################################

# captures
[[ -d ${SHARP_ORCHESTRATOR_WORKING_DIR}/backups ]] || mkdir ${SHARP_ORCHESTRATOR_WORKING_DIR}/backups

# Empty tmp directory
[[ -d ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/ ]] && rm -rf ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/* || mkdir ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp
touch ${SHARP_ORCHESTRATOR_WORKING_DIR}/tmp/orchestrator_cmd.txt

# Empty log directory 
[[ -d ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/ ]] && rm -rf ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs/* || mkdir ${SHARP_ORCHESTRATOR_WORKING_DIR}/logs

# Create error log file
touch ${ERROR_LOG_FILE}

# Empty or create sa.log
[[ -e ${LOG_FILE} ]] && > ${LOG_FILE} || touch ${LOG_FILE}

# Reset status
reset_network_status

while getopts ":i" opt; do
  case ${opt} in
    i)
      interactive_mode=true
      ;;
    :)
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

if [[ "${interactive_mode}" == "true" ]]; then
  orchestrator_loop &
  loop_pid=$!

  while true; do
    main_menu
  done

else
  orchestrator_loop	
fi
