#!/usr/bin/env bash

# Global variables
AVH_TOKEN=""
BEARER=""
PROJECT=""
INSTANCE=""
MODEL="imx8mp-evk"
IP=""

# Static variables
AVH_URL="https://app.avh.arm.com/api/v1"
BASEDIR=$(dirname "$0")

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} [--help | -h] [--token | -t TOKEN] [--model | -m MODEL] OPERATION
CLI tool for Arm Virtual Hardware.
    --help  | -h         display this help and exit
    --token | -t TOKEN   specify API token
    --model | -m MODEL   specify AVH model when using create. Ignored otherwise
                         MODEL should be one of imx8mp-evk (default), rpi4b or stm32u5-b-u585i-iot02a
    OPERATION should be one of:
    create | -c          create an Arm Virtual Hardware instance
    delete | -d          delete the Arm Virtual Hardware instance create by this script
    start  | -l          start the Arm Virtual Hardware instance created by this script
    stop   | -s          stop the Arm Virtual Hardware instance created by this script
EOF
}

# Get token from settings folder or ask the user
get_token() {
  if [ "$AVH_TOKEN" == "" ]; then
    if [ -f $BASEDIR/.avh/token.txt ]; then
      AVH_TOKEN=$(cat $BASEDIR/.avh/token.txt)
      echo "Using token found in $BASEDIR/.avh/token.txt"
      return
    else
      mkdir -p $BASEDIR/.avh
      echo "Token not found in $BASEDIR/.avh/avh_token.txt. Please enter token:"
      read AVH_TOKEN
      echo "Saving token in $BASEDIR/.avh/token.txt"
      echo $AVH_TOKEN > $BASEDIR/.avh/token.txt
    fi
  fi
}

# Get bearer token
get_bearer() {
  REQ="{\"apiToken\": \"$AVH_TOKEN\"}"
  BEARER=$(curl -s -X POST "$AVH_URL/auth/login" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "$REQ" \
    | jq -r '.token' )
}

# Get project
get_project() {
  PROJECT=$(curl -s -X GET "$AVH_URL/projects" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $BEARER" \
    | jq -r '.[]' | jq -r '.id' )
}

# Get instance IP
get_ip() {
  if [ -f $BASEDIR/.avh/instance.txt ]; then
    INSTANCE=$(cat $BASEDIR/.avh/instance.txt)
  else
    return
  fi
  IP=$(curl -s -X GET "$AVH_URL/instances" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $BEARER" \
    | jq -r ".[] | select(.id==\"$INSTANCE\")" | jq -r '.serviceIp' )
  echo $IP > $BASEDIR/ip.txt
  echo "Instance IP is: $IP"
  echo "To connect to the console: nc $IP 2000"
  echo "IP information has been saved in $BASEDIR/ip.txt"
}

# Get ovpn certificate
get_ovpn() {
  if [ -f $BASEDIR/.avh/instance.txt ]; then
    INSTANCE=$(cat $BASEDIR/.avh/instance.txt)
  else
    return
  fi
  curl -s -X GET "$AVH_URL/projects/$PROJECT/vpnconfig/ovpn" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer $BEARER" > $BASEDIR/avh.ovpn
  echo "OpenVPN certificate has been saved in $BASEDIR/avh.ovpn"
}

# Create instance
create() {
  if [ -f $BASEDIR/.avh/instance.txt ]; then
    echo "An instance has already been created. Do you want to start/stop/delete it instead?"
    return
  else
    if [ "$MODEL" == "imx8mp-evk" ]; then
      OS="2.2.0"
    fi
    if [ "$MODEL" == "rpi4b" ]; then
      OS="11.2.0"
    fi
    if [ "$MODEL" == "stm32u5-b-u585i-iot02a" ]; then
      OS="1.1.0"
    fi
    REQ="{\"project\":\"$PROJECT\",\"name\":\"$MODEL Created via API\",\"flavor\":\"$MODEL\",\"os\":\"$OS\"}"
    INSTANCE=$(curl -s -X POST "$AVH_URL/instances" \
      -H "Accept: application/json" \
      -H "Authorization: Bearer $BEARER" \
      -H "Content-Type: application/json" \
      -d "$REQ" \
      | jq -r '.id' )
    echo $INSTANCE > $BASEDIR/.avh/instance.txt
  fi

  # Wait for instance to be ready
  CMD="curl -s -X GET \"$AVH_URL/instances/$INSTANCE/state\" \
    -H \"Accept: application/json\" \
    -H \"Authorization: Bearer $BEARER\" "
  echo "Waiting for instance to be ready"
  STATUS=$(eval $CMD)
  while [ "$STATUS" == "creating" ] ; do
    printf "\r|"
    sleep 2
    printf "\r/"
    sleep 2
    printf "\r-"
    sleep 2
    printf "\r\\"
    sleep 2
    STATUS=$(eval $CMD)
  done
  printf "\rInstance is ready\n"
}

# Start instance
start_instance() {
  if [ ! -f $BASEDIR/.avh/instance.txt ]; then
    echo "An instance could not be found. Do you want to create one instead?"
    return
  else
    INSTANCE=$(cat $BASEDIR/.avh/instance.txt)
    curl -s -X POST "$AVH_URL/instances/$INSTANCE/start" \
      -H "Accept: application/json" \
      -H "Authorization: Bearer $BEARER" \
      -H "Content-Type: application/json" \
      -d '{"paused":false}'
    # Wait for instance to be ready
    CMD="curl -s -X GET \"$AVH_URL/instances/$INSTANCE/state\" \
      -H \"Accept: application/json\" \
      -H \"Authorization: Bearer $BEARER\" "
    echo "Waiting for instance to be ready"
    STATUS=$(eval $CMD)
    while [ "$STATUS" == "starting" ] ; do
      printf "\r|"
      sleep 2
      printf "\r/"
      sleep 2
      printf "\r-"
      sleep 2
      printf "\r\\"
      sleep 2
      STATUS=$(eval $CMD)
    done
    printf "\rInstance is ready\n"
  fi
}

# Stop instance
stop_instance() {
  if [ ! -f $BASEDIR/.avh/instance.txt ]; then
    echo "An instance could not be found. Do you want to create one instead?"
    return
  else
    INSTANCE=$(cat $BASEDIR/.avh/instance.txt)
    curl -s -X POST "$AVH_URL/instances/$INSTANCE/stop" \
      -H "Accept: application/json" \
      -H "Authorization: Bearer $BEARER" \
      -H "Content-Type: application/json" \
      -d '{"soft":false}'
  fi
}

# Delete instance
delete() {
  if [ ! -f $BASEDIR/.avh/instance.txt ]; then
    echo "An instance could not be found. Do you want to create one instead?"
    return
  else
    INSTANCE=$(cat $BASEDIR/.avh/instance.txt)
    curl -s -X DELETE "$AVH_URL/instances/$INSTANCE" \
      -H "Accept: application/json" \
      -H "Authorization: Bearer $BEARER"
    rm $BASEDIR/.avh/instance.txt
    rm $BASEDIR/ip.txt
    rm $BASEDIR/avh.ovpn
  fi
}

avh_create() {
  get_token
  get_bearer
  get_project
  echo "Creating instance"
  create
  get_ip
  get_ovpn
}

avh_start() {
  get_token
  get_bearer
  get_project
  echo "Starting instance"
  start_instance
  get_ip
  get_ovpn
}

avh_stop() {
  get_token
  get_bearer
  get_project
  echo "Stopping instance"
  stop_instance
}

avh_delete() {
  get_token
  get_bearer
  get_project
  echo "Deleting instance"
  delete
}


#################
# Parse command #
#################

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    '--help')   set -- "$@" '-h'   ;;
    '--token')  set -- "$@" '-t'   ;;
    '--model')  set -- "$@" '-m'   ;;
    'create')   set -- "$@" '-c'   ;;
    'delete')   set -- "$@" '-d'   ;;
    'start')    set -- "$@" '-l'   ;;
    'stop')     set -- "$@" '-s'   ;;
    *)          set -- "$@" "$arg" ;;
  esac
done

OPTIND=1
# Resetting OPTIND is necessary if getopts was used previously in the script.
# It is a good idea to make OPTIND local if you process options in a function.

while getopts ht:m:cdls opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        t)
            AVH_TOKEN=$OPTARG
            ;;
        m)
            MODEL=$OPTARG
            if [[ "$MODEL" != "imx8mp-evk" ]] && \
               [[ "$MODEL" != "rpi4b" ]] && \
               [[ "$MODEL" != "stm32u5-b-u585i-iot02a" ]]; then
              echo "Model is unknown"
              show_help
              exit 1
            fi
            ;;
        c)
            avh_create
            exit 0
            ;;
        d)
            avh_delete
            exit 0
            ;;
        l)
            avh_start
            exit 0
            ;;
        s)
            avh_stop
            exit 0
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done
shift "$((OPTIND-1))"   # Discard the options and sentinel --

echo "I'm not sure what to do..."
echo "Please enter one of the following --create, --start, --stop, --delete."
show_help
exit 1

