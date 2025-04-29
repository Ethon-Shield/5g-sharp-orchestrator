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

# Mandatory arguments
IMAGES_VERSION="2.1.0"

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
	echo "$0 -v <version>"
  echo ""
  echo "Mandatory arguments:"
  echo "-v <version>  Version of OAI images to download"
  echo ""
  echo "Optional arguments:"
  echo "-h            print this help message"
}

while getopts "v:h" opt; do
  case $opt in
    v)
      IMAGES_VERSION="${OPTARG}"
      if ! [[ "${IMAGES_VERSION}" =~ ^[0-9].[0-9].[0-9]$ ]]; then
        echo "ERROR: version does not have a valid format"
        help
        exit 1
      else
        IMAGES_VERSION="v${OPTARG}"
      fi
      ;;
    h) help; exit 1;;
    :) exit 1 ;;
    ?) exit 1 ;;
  esac
done

if ((OPTIND == 1)); then
  echo "ERROR: No options specified"
  exit 1
fi

# Check for mandatory arguments
if [[ -z "${IMAGES_VERSION}" ]]; then
  echo "ERROR: Missing mandatory arguments: <version>"
  exit 1
fi

echo "Docker images with version ${IMAGES_VERSION} are going to be downloaded, do you want to continue? [y/n]"
read continue_script
if ! [[ "${continue_script}" == "y" ]]; then
  echo "Exiting script"
  exit 1
fi

images="amf nrf upf smf udr udm ausf upf-vpp nssf pcf nef lmf spgwu-tiny"

# Checking if images exist
echo "Checking if images exist..."
images_to_download=""
for image in ${images}; do
  image_exists=$(docker manifest inspect "oaisoftwarealliance/oai-${image}:${IMAGES_VERSION}" 2>&1 | grep -c "no such manifest")
  if [[ ${image_exists} -ge 1 ]]; then 
    echo "oai-${image} does not exist, please check version"
  else
    echo "oai-${image} exists"
    images_to_download+="${image} "
  fi
done 

if [[ -z "${images_to_download}" ]]; then
  echo "No images to download, exiting..."
  exit 1
else 
  echo "The images that can be downloaded are: ${images_to_download}"
  echo "Do you want to continue? [y/n]"
  read continue_downloading_images
  if ! [[ "${continue_downloading_images}" == "y" ]]; then
    echo "Exiting..."
    exit 1
  fi
fi

# Pull images
echo "Pulling IMAGES..."
echo ""
for image in ${images_to_download}; do
  docker pull oaisoftwarealliance/oai-${image}:${IMAGES_VERSION}
done
docker pull oaisoftwarealliance/trf-gen-cn5g:latest
