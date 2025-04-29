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

DB_CMD=""
IMSI=""
KI=""
OPC="" 

######################################################
# Display database manager help menu
#
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Print help menu indications to stdout
######################################################

function help {
  echo ""
  echo "$0 -c <command> -i <imsi> [-k <ki>] [-o <opc>]"
  echo ""
  echo "Mandatory arguments:"
  echo "-c <command>  add, update, remove"
  echo "  add         Adds a new subscriber to the database. Requires -i <imsi> -k <ki> -o <opc>"
  echo "  update      Updates the information of a subscriber. Requires -i <imsi> -k <ki> -o <opc>"
  echo "  remove      Removes an existing subscriber from the database. Requires -i <imsi>"
  echo ""
  echo "Optional arguments:"
  echo "-h            print this help message"
}

#############################################################
# Check if a given subscriber is already in NRCORE database 
#
# Globals:
#   NRCORE_TECH
#   DDBB_FILE_PATH
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   imsi= Subscriber imsi
# Outputs:
#   1 if subscriber is already in database, 0 otherwise
#############################################################

function is_subscriber_in_db {
  local imsi=$1
  local is_imsi_in_ddbb=0

  if [[ "${NRCORE_TECH}" == "OAI" ]]; then
    if [[ -f ${DDBB_FILE_PATH} ]]; then
      grep -q "${imsi}" ${DDBB_FILE_PATH}
      [[ $? -eq 0 ]] && is_imsi_in_ddbb=1
    fi
  elif [[ "${NRCORE_TECH}" == "OPEN5GS" ]]; then
    ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/open5gs-dbctl showfiltered | grep -q "${imsi}" 2>&1 > /dev/null	  
    [[ $? -eq 0 ]] && is_imsi_in_ddbb=1
  fi

  echo "${is_imsi_in_ddbb}"
}

#############################################################
# Remove subscriber info from NRCORE database
#
# Globals:
#   NRCORE_TECH
#   DDBB_FILE_PATH
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   imsi= Subscriber imsi
# Outputs:
#   None
#############################################################

function remove_subscriber_from_db {
  local imsi=$1

    if [[ "${NRCORE_TECH}" == "OAI" ]]; then
      line_number=$(grep -n "${imsi}" ${DDBB_FILE_PATH} | cut -d: -f1)
      sed -i -e "${line_number}d" ${DDBB_FILE_PATH} 

    elif [[ "${NRCORE_TECH}" == "OPEN5GS" ]]; then
      ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/open5gs-dbctl remove "${imsi}" 2>&1 > /dev/null
    fi
}

#############################################################
# Add subscriber info to NRCORE database
#
# Globals:
#   NRCORE_TECH
#   DDBB_FILE_PATH
#   SHARP_ORCHESTRATOR_WORKING_DIR
# Arguments:
#   imsi= Subscriber imsi
#   ki= Subscriber ki
#   opc= Subscriber opc
# Outputs:
#   None
#############################################################

function add_subscriber_to_db {
  local imsi=$1
  local ki=$2
  local opc=$3


  if [[ "${NRCORE_TECH}" == "OAI" ]]; then

    insert_db="INSERT INTO \`AuthenticationSubscription\` (\`ueid\`, \`authenticationMethod\`, \`encPermanentKey\`, \`protectionParameterId\`, \`sequenceNumber\`, \`authenticationManagementField\`, \`algorithmId\`, \`encOpcKey\`, \`encTopcKey\`, \`vectorGenerationInHss\`, \`n5gcAuthMethod\`, \`rgAuthenticationInd\`, \`supi\`) VALUES ('__IMSI__', '5G_AKA', '__KI__', '__KI__', '{\"sqn\": \"000000000020\", \"sqnScheme\": \"NON_TIME_BASED\", \"lastIndexes\": {\"ausf\": 0}}', '8000', 'milenage', '__OPC__', NULL, NULL, NULL, NULL, '__IMSI__');"

    sed -i "s/-- __NEW_USER__/${insert_db}\n-- __NEW_USER__/g" ${DDBB_FILE_PATH}
    sed -i -e "s/__IMSI__/${imsi}/g" -e "s/__KI__/${ki}/g" -e "s/__OPC__/${opc}/g" ${DDBB_FILE_PATH} 

  elif [[ "${NRCORE_TECH}" == "OPEN5GS" ]]; then
    ${SHARP_ORCHESTRATOR_WORKING_DIR}/bin/open5gs-dbctl add "${imsi}" "${ki}" "${opc}" 2>&1 > /dev/null
  fi

}

no_args="true"
while getopts "c:i:k:o:h" opt; do
  case $opt in
    c)
      DB_CMD="${OPTARG}"
      if [[ "${DB_CMD}" != "add" && "${DB_CMD}" != "update" && "${DB_CMD}" != "remove" ]]; then
        logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "The command ${command} is not within the options"
        exit 1
      fi
      ;;
    i)
      IMSI=${OPTARG}
      if ! [[ "${IMSI}" =~ ^[0-9]{15}$ ]]; then
        logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "IMSI value not valid, it has to be 15 digits long"
        exit 1
      fi
      ;;
    k)
      KI=${OPTARG}
      if ! [[ "${KI}" =~ ^[0-9a-fA-F]{32}$ ]]; then
        logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Ki value not valid, it has to be 32 characters long (in hex)"
        exit 1
      fi
      ;;
    o)
      OPC=${OPTARG}
      if ! [[ "${OPC}" =~ ^[0-9a-fA-F]{32}$ ]]; then
        logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "OPc value not valid, it has to be 32 characters long (in hex)"
        exit 1
      fi
      ;;
    h) help; exit 1;;
    :) exit 1 ;;
    ?) exit 1 ;;
  esac
done

if ((OPTIND == 1)); then
  logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "No options specified"
  exit 1
fi

# Check for mandatory arguments
if [[ "${DB_CMD}" == "add" || "${DB_CMD}" == "update" ]]; then
  if [[ -z "${IMSI}" || -z "${KI}" || -z "${OPC}" ]]; then
    logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Missing mandatory arguments: <imsi>, <ki> and <opc>"
    exit 1
  fi
else
  if [[ -z "${IMSI}" ]]; then
    logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Missing mandatory arguments <imsi>"
    exit 1
  fi
fi

case ${DB_CMD} in
  "add")
    # Check if the subscriber is already in the database
    if [[ $(is_subscriber_in_db "${IMSI}") -eq 1 ]]; then
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber already in database"
      exit 1
    fi

    add_subscriber_to_db "${IMSI}" "${KI}" "${OPC}"
    
    # Check if it has been added correctly
    if [[ $(is_subscriber_in_db "${IMSI}") -eq 1 ]]; then
      logging "INFO" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber added successfully to the database"
    else
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber could not be added to the database"
      exit 1
    fi
    ;;

  "update")
    
    # Check if the subscriber is in the database
    if [[ $(is_subscriber_in_db "${IMSI}") -eq 0 ]]; then
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber with imsi ${IMSI} not found in database"
      exit 1
    fi

    remove_subscriber_from_db "${IMSI}"
    add_subscriber_to_db "${IMSI}" "${KI}" "${OPC}"
    
    if [[ $(is_subscriber_in_db "${IMSI}") -eq 1 ]]; then
      logging "INFO" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber updated successfully in the database"
    else
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber could not be updated in the database"
      exit 1
    fi 
    ;;
  "remove")
    # Check if the subscriber is in the database
    if [[ $(is_subscriber_in_db "${IMSI}") -eq 0 ]]; then
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "There is no subscriber with that IMSI to remove"
      exit 1
    fi

    remove_subscriber_from_db "${IMSI}"
    
    # Check if it has been removed correctly
    if [[ $(is_subscriber_in_db "${IMSI}") -eq 1 ]]; then
      logging "ERROR" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber could not be removed from the database"
      exit 1
    else
      logging "INFO" "ORCH" "${SHARP_ORCHESTRATOR_IP_ADDRESS}" "Subscriber removed successfully from the database"
    fi

    ;;
esac
