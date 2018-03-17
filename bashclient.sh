#!/usr/bin/env bash

#/
#/ Usage: 
#/ ./bashclient.sh OPTION
#/ 
#/ Description:
#/ CLI HTTP "client" and a bash HTTP "library" for sending HTTP requests
#/ 
#/ Examples:
#/ ./bashclient.sh -u http://google.com
#/ ./bashclient.sh -s google.com -p /#q=bashclient.sh+github
#/ You can source this file and use it's functions
#/ get_http [url]
#/
#/ Options:

# Great post by Thiht - https://dev.to/thiht/shell-scripts-matter
usage() { grep '^#/' "$0" | cut -c4- ; exit 0 ; }
expr "$*" : ".*-h" > /dev/null && usage
expr "$*" : ".*--help" > /dev/null && usage

declare -x ACCEPT="application/json"
declare -x CODE=""
declare -x PORT="80"
declare -x SERVER=""
declare -x SCHEME="http"
declare -x URLPATH="/"
declare -x WRITE=false

declare -a HTTP_RESPONSE=(
   [400]="Bad Request"
   [401]="Unauthorized"
   [403]="Forbidden"
   [404]="Not Found"
   [500]="Internal Server Error"
   [502]="Bad Gateway"
   [503]="Service Unavailable"
)

# Parse URL into SCHEME, SERVER, PORT AND URLPATH
parse_url() {
  URL="${1}"
  SCHEME=$(echo "${URL}" | cut -f1 -s -d':' | tr -d ' ')
  if [[ $SCHEME != "http" ]];then
    echo "Sorry $SCHEME not supported for the time being!"
    exit 0
  fi
  SERVER=$(echo "${URL}" | cut -f2 -s -d':' | cut -f3 -s -d'/')
  
  # Check if URL contains PORT, if value is number
  if [[ $(echo "${URL}" | cut -f3 -s -d':' | cut -f1 -s -d'/') =~ ^[0-9]+$ ]]; then
    PORT=$(echo "${URL}" | cut -f3 -s -d':' | cut -f1 -s -d'/')
    URLPATH=/$(echo "${URL}" | cut -f3 -s -d':' | cut -f2- -s -d'/' | tr -s ' ' '/')
  else
    URLPATH=/$(echo "${URL}" | cut -f2 -s -d':' | cut -f4- -s -d'/' | tr -s ' ' '/')
  fi
}

# Request are being made with /dev/tcp
req() {
  exec 3<>/dev/tcp/"${SERVER}"/"${PORT}"
  echo -e "GET $URLPATH HTTP/1.1\\r\\nHost: $SERVER\\r\\nUser-Agent:bashclient0.1\\r\\nAccept: $ACCEPT\\r\\nConnection: close\\r\\n\\r\\n" >&3
  cat <&3
}

# Parse HTTP response
parse_res() {
  # Read response line by line
  while read -r line; do
    # Set HTTP code
    if [[ "${line}" == HTTP* ]]; then
      CODE=$(echo "${line}" | cut -f2 -d' ')
      continue
    fi
    # If codes are 301 or 302 we need to get new Location and execute request to that new location
    if ([[ "${CODE}" == '301' ]] || [[ "${CODE}" == '302' ]]) && [[ "${line}" == Location* ]]; then
      # Location header can be in form of a full URL
      if [[ $(echo "${line}" | cut -f2 -s -d':' | tr -d ' ' ) == http* ]]; then
        SCHEME=$(echo "${line}" | cut -f2 -s -d':' | tr -d ' ')
        SERVER=$(echo "${line}" | cut -f3 -s -d':' | cut -f3 -s -d'/')
        URLPATH=/$(echo "${line}" | cut -f3 -s -d':' | cut -f4- -s -d'/' | tr -s ' ' '/')
      # or relative
      else
        URLPATH=$(echo -e "${line}" | cut -f2 -s -d':' | tr -d ' \r')
      fi
      if [[ $SCHEME != "http" ]];then
        echo "Sorry $SCHEME not supported for the time being!"
        exit 0
      fi
      # Return SERVER and URLPATH to main function exit with 1 and break loop
      echo "${SERVER} ${URLPATH}"
      exit 1
      break
    fi
    # If code is 200 and line is empty we can start printing response from the next line
    if [[ "${CODE}" == '200' ]] && [[ "${line:0:1}" = $'\r' ]]; then
      WRITE=true
      continue
    fi
    if [[ "${CODE}" == '200' ]] && [[ "${WRITE}" = true ]]; then
      echo "${line}"
      continue
    fi
    if [[ "${CODE}" =~ 400|401|403|404|500|502|503 ]]; then
      echo "${CODE} ${HTTP_RESPONSE[$CODE]}"
      exit 0
    fi
  done <<< "${1}"
}

get_http() {
  URL="${1:-""}"
  if [[ $URL ]]; then
    parse_url "${URL}"
  elif [[ ! $SERVER ]]; then
    echo "ERROR: You must specify url or a server!"
    exit 1
  fi
  # Loop for executing requests
  while true; do
    # Send request
    response="$(parse_res "$(req)")"
    code="$?"
    # If return code is 1 it's a redirect
    if [[ "${code}" -eq 1 ]]; then
      # Set new values for SERVER and URLPATH and continue loop
      read -r SERVER URLPATH < <(echo "${response}")
      continue
    elif [[ "${code}" -eq 0 ]]; then
      # If return code is 0 print response and break loop
      echo "${response}"
      break
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then

  # Fantastic solution from Bruno Bronosky - http://stackoverflow.com/a/14203146
  while [[ $# -gt 1 ]]; do
    key="$1"

    case "${key}" in
#/   -u, --url url 
        -u|--url)
          URL="${2}"
          shift
        ;;
#/   -s, --server servername
        -s|--server)
          SERVER="${2}"
          shift
        ;;
#/   -p, --path urlpath with leading /
        -p|--path)
          URLPATH="${2}"
          shift
        ;;
#/   -a, --accept accept-header Accept request-header defaults to application/json
        -a|--accept)
          ACCEPT="${2}"
          shift
        ;;
#/   -h, --help: Display this help message     
        *)
          usage
        ;;
    esac
    shift
  done

  get_http "${URL}"
fi