#!/bin/bash
#
# Written by DStrickler Thu, Mar 25, 2021
# Gets the value from an Indigo variable and feeds it back in Nagios format.
#
# Based on examples from
# https://wiki.indigodomo.com/doku.php?id=indigo_s_restful_urls
#
round() {
  printf "%.${2}f" "${1}"
}

# Setup access to Indigo itself. Make sure the username and password are correct.
USERNAME="your_indigo_username"
PASSWORD="your_indigo_password"
SERVER="127.1.1.1"
PORT="8176"

# Get the CLI params.
UNIT="" # Default to nothing
while getopts H:V:w:c:t:u: flag; do
  case "${flag}" in
  V) VARIABLE_NAME=${OPTARG} ;;
  w) WARNING_LEVEL=${OPTARG} ;;
  c) CRITICAL_LEVEL=${OPTARG} ;;
  t) LEVEL_DIRECTION=${OPTARG} ;;
  u) UNIT=${OPTARG} ;;
  esac
done

if [ -v "${VARIABLE_NAME}" ] || [ -z "${VARIABLE_NAME}" ]; then
  echo "CONFIGURATION CRITICAL - No -variable argument supplied for Variable name. Use string a like 'wc_tempf' with no spaces."
  exit 3
fi
if [ -v "${WARNING_LEVEL}" ] || [ -z "${WARNING_LEVEL}" ]; then
  echo "CONFIGURATION CRITICAL - No -w argument supplied for level. Use an numeric minimum value for warning."
  exit 3
fi
if [ -v "${CRITICAL_LEVEL}" ] || [ -z "${CRITICAL_LEVEL}" ]; then
  echo "CONFIGURATION CRITICAL - No -c argument supplied for level. Use an numeric minimum value for critical."
  exit 3
fi
if [ -v "${LEVEL_DIRECTION}" ] || [ -z "${LEVEL_DIRECTION}" ]; then
  echo "CONFIGURATION CRITICAL - No -t argument supplied for level direction. Use an string value of 'above' or 'below' to indicate the trigger direction. Currently set to ${LEVEL_DIRECTION}"
  exit 3
fi

# Poll the internal temperature of the Device
VALUE=$(/usr/bin/curl -s -u ${USERNAME}:${PASSWORD} --digest http://${SERVER}:${PORT}/variables/${VARIABLE_NAME}.json | grep "value" | cut -d':' -f2 | cut -d',' -f 1 | xargs)

# Bash can't deal with floating point (like 5.231 Kw), so just lob off the decimal points.
VALUE=$(round ${VALUE} 0)

TRAILING_DETAILS="- ${VALUE}${UNIT}|${VARIABLE_NAME}=${VALUE};${WARNING_LEVEL};${CRITICAL_LEVEL}"

# Note Integer and String comparisons use different expressions
# https://tldp.org/LDP/abs/html/comparison-ops.html
if [ -v ${VALUE} ] || [ -z ${VALUE} ]; then
  echo "CRITICAL - reading is '${VALUE}' which usually means the data couldn't be retrieved from Indigo."
  exit 3
fi
if [ $LEVEL_DIRECTION = "above" ] || [ $LEVEL_DIRECTION = "up" ]; then
  if [ $VALUE -ge $CRITICAL_LEVEL ]; then
    echo "CRITICAL $TRAILING_DETAILS"
    exit 2
  elif [ $VALUE -ge $WARNING_LEVEL ]; then
    echo "WARNING $TRAILING_DETAILS"
    exit 1
  else
    echo "OK $TRAILING_DETAILS"
    exit 0
  fi
elif [ "$LEVEL_DIRECTION" = "below" ] || [ "$LEVEL_DIRECTION" = "down" ]; then
  if [ $VALUE -le $CRITICAL_LEVEL ]; then
    echo "CRITICAL $TRAILING_DETAILS"
    exit 2
  elif [ $VALUE -le $WARNING_LEVEL ]; then
    echo "WARNING $TRAILING_DETAILS"
    exit 1
  else
    echo "OK $TRAILING_DETAILS"
    exit 0
  fi
  else
    echo "CRITICAL: The '-t' value needs to be 'above' or 'below'."
fi
