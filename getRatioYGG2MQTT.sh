#!/bin/bash
#
# getRatioYGG2MQTT.sh
#
# Ready to use "simple" script, to getYGG Ratio

BASENAME=`basename "$0"`
DIRNAME=`dirname "$0"`

TMPDIR=~/tmp                            # You can customize this, if you dont want to create tmp dir in HOMEDIR
TMP="${TMPDIR}/${BASENAME}.$$.tmp"
TMP_JSON="${TMPDIR}/${BASENAME}.$$.json"

[ ! -d "${TMPDIR}" ] && mkdir "${TMPDIR}"

# YOU NEED TO CUSTOMISE THIS VARIABLES !!!!
YGG_HOST="www.yggtorrent.li"                    # The current YGG Hostname
YGG_URL="https://${YGG_HOST}"                   # The current YGG URL
FLARESOLVR_URL="http://192.168.0.1:8191"        # Your FlareSolvrr API URL
YGG_LOGIN="YGG_LOGIN"                           # YGG Login
YGG_PASSWORD="YGG_PASSWORD"                     # YGG Password

# ONLY to PUSH information to MQTT Broker
#MQTT_HOST="mqtt.domain.local"           # If Empty, no MQTT will be done
#MQTT_PORT="1883"
#MQTT_TOPIC="app/yggtorrent/account"

# END OF REQUIRED CUSTOMIZATION

TIMEOUT=60000
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleW..."

unset DEBUG
#DEBUG="true" # This will show your password in log

#################################################################################################################
# Creating a new FlareSolvrr session
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: Content-Type: application/json' -d '{"cmd": "sessions.create"}' > "${TMP}"
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to create FlareSolvrr session" >&2
        cat "${TMP}" >&2
        rm -f "${TMP}"
        exit 10
fi

#################################################################################################################
# SessionID Extraction
SESSION_ID=`cat "${TMP}" | jq '.session' 2>/dev/null | tr -d '"'`

if [ -z "${SESSION_ID}" ];then
        echo "[ERROR] Unable to extract SessionID" >&2
        cat "${TMP}" >&2
        rm -f "${TMP}"
        exit 20
fi

echo "[INFO] SessionID: ${SESSION_ID}" >&2
DESTROY_JSON="{\"cmd\": \"sessions.destroy\",\"session\":\"${SESSION_ID}\"}"
#HEADERS="\"headers\": {\"Accept\": \"application/json, text/javascript, */*; q=0.01\", \"x-requested-with\": \"XMLHttpRequest\"}"
HEADERS="\"headers\": {\"Accept\": \"application/json, text/javascript, */*; q=0.01\"}"
#HEADERS="\"headers\": {\"Host\": \"${YGG_HOST}\"}"

#################################################################################################################
# First GET
echo "[INFO] GET ${YGG_URL}..." >&2
QUERY="{\"cmd\": \"request.get\",\"url\":\"${YGG_URL}/\",\"userAgent\": \"${USER_AGENT}\",\"maxTimeout\": ${TIMEOUT},\"session\": \"${SESSION_ID}\",${HEADERS}}"
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${QUERY}" | python -m json.tool > "${TMP}"
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Ygg doesn't respond" >&2
        cat "${TMP}" >&2
fi

STATUS=`cat "${TMP}" | jq ".status" | tr -d '"'`
RESPONSE=`cat "${TMP}" | jq ".solution.response"`
REFERER=`cat "${TMP}" | jq ".solution.url" | sed 's/^"//' | sed 's/"$//'`

if [ -z "${REFERER}" ];then
        echo "[ERROR] Referer seems to be null. Not normal." >&2
        STATUS="KO"
fi

#YGG_URL=`echo "${REFERER}" | sed 's/www[0-9]/www/'`              
YGG_URL=`echo "${REFERER}" | sed 's#/$##'`                        
echo "[INFO] new URL : ${YGG_URL}"                                

[ "${RESPONSE}" = "null" ] && unset Response

if [ "${STATUS}" != "ok" ];then
        MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
        echo "[ERROR] YGG seems to response abnormally" >&2
        [ -n "${DEBUG}" ] && echo "[DEBUG] Query : " >&2
        [ -n "${DEBUG}" ] && echo "${QUERY}" >&2
        echo "[${STATUS}] ${MSG}" >&2
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
        RC=$?

        if [ ${RC} -ne 0 ];then
                echo "[ERROR] Unable to clean FlareSolvrr session" >&2
                cat "${TMP}" >&2
        fi

        STATUS=`cat "${TMP}" | jq ".status" | tr -d '"'`
        if [ "${STATUS}" != "ok" ];then
                MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
                echo "[${STATUS}] ${MSG}" >&2
        fi

        rm -f "${TMP}" "${TMP_JSON}"
        exit 25
fi



## DEBUG First GET
[ -n "${DEBUG}" ] && echo "[DEBUG] Response : " >&2
[ -n "${DEBUG}" ] && cat "${TMP}" | python -m json.tool >&2

#################################################################################################################
# Creating login request
cat > "${TMP_JSON}" <<- EOF
{
          "cmd": "request.post",
          "url":"${YGG_URL}/user/login",
          "userAgent": "${USER_AGENT}",
          "maxTimeout": ${TIMEOUT},
          "session":"${SESSION_ID}",
          "postData": "id=${YGG_LOGIN}&pass=${YGG_PASSWORD}&submit=&ci_csrf_token=",
          "headers": {
            "Content-Type": "application/x-www-form-urlencoded",
                "referer": "${REFERER}",
                "X-Requested-With": "XMLHttpRequest"
          }
}
EOF
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to create YGG query" >&2
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
        RC=$?

        if [ ${RC} -ne 0 ];then
                echo "[ERROR] Unable to clean FlareSolvrr session" >&2
                cat "${TMP}" >&2
        fi

        STATUS=`cat "${TMP}" | jq ".status" | tr -d '"'`
        if [ "${STATUS}" != "ok" ];then
                MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
                echo "[${STATUS}] ${MSG}" >&2
        fi

        rm -f "${TMP}" "${TMP_JSON}"
        exit 30
fi


#################################################################################################################
# Login...
echo "[INFO] Login ygg..." >&2
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "@${TMP_JSON}" > "${TMP}"
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] YGG Login Failed" >&2
        echo "Query:" >&2
        cat "${TMP_JSON}" >&2

        echo "Response:" >&2
        cat "${TMP}" >&2
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
        RC=$?

        if [ ${RC} -ne 0 ];then
                echo "[ERROR] Unable to clean FlareSolvrr session" >&2
                cat "${TMP}" >&2
        fi

        STATUS=`cat "${TMP}" | jq ".status" | tr -d '"'`
        if [ "${STATUS}" != "ok" ];then
                MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
                echo "[${STATUS}] ${MSG}" >&2
        fi

        rm -f "${TMP}" "${TMP_JSON}"
        exit 40
fi

#################################################################################################################
# Login verification
STATUS=`cat "${TMP}" | jq '.status' 2>/dev/null | tr -d '"'`
MSG=`cat "${TMP}" | jq '.message' 2>/dev/null | tr -d '"'`
HTTP_CODE=`cat "${TMP}" | jq '.solution.status' 2>/dev/null | tr -d '"'`

if [ "${STATUS}" != "ok" ] || [ "${HTTP_CODE}" != "200" ];then
        echo "[ERROR] YGG login failed. ReturnCode checking is KO" >&2
        echo "[${STATUS}] ${MSG}" >&2
        #echo "Query:" >&2
        #cat "${TMP_JSON}" >&2  # Will show your password !

        #echo "Response:" >&2
        #cat "${TMP}" >&2
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
        RC=$?

        if [ ${RC} -ne 0 ];then
                echo "[ERROR] Unable to clean FlareSolvrr session" >&2
                cat "${TMP}" >&2
        fi

        STATUS=`cat "${TMP}" | jq ".status" | tr -d '"'`
        if [ "${STATUS}" != "ok" ];then
                MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
                echo "[${STATUS}] ${MSG}" >&2
        fi

        rm -f "${TMP}" "${TMP_JSON}"
        exit 50
else
        echo "[INFO] Login ygg OK"
fi

## DEBUG DU LOGIN
[ -n "${DEBUG}" ] && echo "[DEBUG] Query : " >&2
[ -n "${DEBUG}" ] && cat "${TMP_JSON}" | python -m json.tool >&2
[ -n "${DEBUG}" ] && echo "[DEBUG] Response : " >&2
[ -n "${DEBUG}" ] && cat "${TMP}" | python -m json.tool >&2

#################################################################################################################
# Retrieve Ratio
echo "[INFO] GET Ratio..." >&2
HEADERS="\"headers\": {\"Accept\": \"application/json, text/javascript, */*; q=0.01\", \"Content-type\": \"application/json; charset=UTF-8\", \"X-Requested-With\": \"XMLHttpRequest\", \"Referer\": \"${REFERER}\"}"
QUERY="{\"cmd\": \"request.get\",\"url\":\"${YGG_URL}/user/ajax_usermenu\",\"userAgent\": \"${USER_AGENT}\",\"maxTimeout\": ${TIMEOUT},\"session\":\"${SESSION_ID}\",${HEADERS}}"
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${QUERY}" | python -m json.tool  > "${TMP}"
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to get Ratio" >&2
        cat "${TMP}" >&2
fi

#DEBUG="true"

## DEBUG DU RATIO
[ -n "${DEBUG}" ] && echo "[DEBUG] Query : " >&2
[ -n "${DEBUG}" ] && echo "${QUERY}" | python -m json.tool >&2
[ -n "${DEBUG}" ] && echo "[DEBUG] Response : " >&2
[ -n "${DEBUG}" ] && cat "${TMP}" | python -m json.tool  >&2

MESSAGE=`cat "${TMP}" | jq ".message" | tr -d '"'`
STATUS=`cat "${TMP}" | jq ".status" | tr -d '"'`
RESPONSE=`cat "${TMP}" | jq ".solution.response"`
[ "${RESPONSE}" = "null" ] && unset Response

if [ "${STATUS}" != "ok" ];then
        MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
        if echo "${RESPONSE}" | grep "Connection requise pour " > /dev/null;then
                MSG="Need to be connect to do this action"
        fi
        echo "[ERROR] Unable to get ratio" >&2
        echo "[${STATUS}] ${MSG}" >&2
        unset RESPONSE
fi


#################################################################################################################
# FlareSolvrr session cleanup
echo "[INFO] Cleaning session" >&2
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
RCE=$?

if [ ${RCE} -ne 0 ];then
        echo "[ERROR] Unable to clean FlareSolvrr session" >&2
fi

STATUS=`cat "${TMP}" | jq ".status" | tr -d '"'`
if [ "${STATUS}" != "ok" ];then
        MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
        echo "[${STATUS}] ${MSG}" >&2
fi

rm -f "${TMP}" "${TMP_JSON}"

if [ ${RC} -ne 0 ];then
        exit ${RC}
fi

#printf "\n[INFO] Réponse : \n"
#printf "%s\n" "${RESPONSE}"

# Sorry for this hard "on liner"...
echo "${RESPONSE}" \
        | sed 's/^"//' | sed 's/"$//' \
        | sed 's/\\"/"/g' | sed 's/\\\\/\\/g' \
        | sed 's/\\"/"/g' | sed 's/\\\\/\\/g' \
        | perl -MHTML::Entities -pe 'decode_entities($_);' \
        | sed 's/\\"/"/g' | sed 's#\\/#/#g' \
        | sed 's#\\u00e9#é#g' | sed 's#.*<ul>##' \
        | sed 's#strong></a></li.*#strong></a></li>#' \
        | awk '{print "<ul>"$0"</ul>"}' \
        | sed 's/</ </g' > "${TMP}"

#cat "${TMP}"

DOWNLOAD=`cat "${TMP}" | xmllint --xpath '/ul/li/strong[1]' - | sed 's#.*/span> ##' | sed 's# </.*##'`
UPLOAD=`cat "${TMP}" | xmllint --xpath '/ul/li/strong[2]' - | sed 's#.*/span> ##' | sed 's# </.*##'`
RATIO=`cat "${TMP}" | xmllint --xpath '/ul/li[2]/a/strong' - | sed 's/.* : //' | sed 's/[0-9] <.*//'`

[ -z "${DOWNLOAD}" ] && DOWNLOAD="null"
[ -z "${UPLOAD}" ] && UPLOAD="null"
[ -z "${RATIO}" ] && RATIO="null"

RAW_DOWNLOAD="${DOWNLOAD}"
RAW_UPLOAD="${UPLOAD}"

DOWNLOAD=`echo "${DOWNLOAD}" | sed 's/Ko/*1024/'| sed 's/Mo/*1048576/' | sed 's/Go/*1073741824/' | sed 's/To/*1099511627776/' | sed 's/To/*1125899906842624/' | bc `
UPLOAD=`echo "${UPLOAD}" | sed 's/Ko/*1024/'| sed 's/Mo/*1048576/' | sed 's/Go/*1073741824/' | sed 's/To/*1099511627776/' | sed 's/To/*1125899906842624/' | bc `

printf "Download: %s (%s)\n" "${DOWNLOAD}" "${RAW_DOWNLOAD}"
printf "Upload:   %s (%s)\n" "${UPLOAD}" "${RAW_UPLOAD}" 
printf "Ratio:    %s\n" "${RATIO}"

# If no MQTT, stop here
if [ -z "${MQTT_HOST}" ];then
    echo "[INFO] Infos successfuly get"
    exit 0
fi

JSON_DATA="{\"ratio\": ${RATIO}, \"upload\": ${UPLOAD}, \"download\": ${DOWNLOAD}, \"rawUpload\": \"${RAW_UPLOAD}\", \"rawDownload\": \"${RAW_DOWNLOAD}\" }"

# Push info in MQTT
mosquitto_pub -h "${MQTT_HOST}" -p "${MQTT_PORT}" -m "${JSON_DATA}" -t "${MQTT_TOPIC}"
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to push message in MQTT" >&2
        exit 100
fi

echo "[INFO] Infos successfuly uploaded to MQTT"
