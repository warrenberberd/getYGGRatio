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
YGG_HOST="www.yggtorrent.wtf"                   # The current YGG Hostname
YGG_URL="https://${YGG_HOST}"                   # The current YGG URL
FLARESOLVR_URL="http://192.168.0.1:8191"        # Your FlareSolvrr API URL
YGG_LOGIN="YGG_LOGIN"                           # YGG Login
YGG_PASSWORD="YGG_PASSWORD"                     # YGG Password

# ONLY to PUSH information to MQTT Broker
#MQTT_HOST="mqtt.domain.local"           # If Empty, no MQTT will be done
#MQTT_PORT="1883"
#MQTT_TOPIC="app/yggtorrent/account"
#MQTT_USERNAME="mqttUser"               # OPTIONNAL
#MQTT_PASSWORD="mqttSecretPassword"     # OPTIONNAL
# END OF REQUIRED CUSTOMIZATION

TIMEOUT=60000
#USER_AGENT="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:108.0) Gecko/20100101 Firefox/108.0"
#USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0"

unset DEBUG
#DEBUG="true" # This will show your password in log

#################################################################################################################
# Creating a new FlareSolvrr session
echo "[INFO] Creating FlareSolvrr Session..." >&2
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d '{"cmd": "sessions.create"}' > "${TMP}"
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to create FlareSolvrr session" >&2
        cat "${TMP}" >&2
        rm -f "${TMP}"
        exit 10
fi


#################################################################################################################
# SessionID Error verification
STATUS=`cat "${TMP}" | jq -r '.status'`
MESSAGE=`cat "${TMP}" | jq -r '.message'`
if [ "${STATUS}" = "error" ];then
        echo "[ERROR] Unable to create session" >&2
        echo "${MESSAGE}" >&2
        exit 11
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
#HEADERS="\"headers\": {\"Accept\": \"*/*\"}"
#HEADERS="\"headers\": {\"Host\": \"${YGG_HOST}\"}"

#################################################################################################################
# First GET
echo "[INFO] GET ${YGG_URL}..." >&2
unset UAGENT
[ -n "${USER_AGENT}" ] && UAGENT="\"userAgent\": \"${USER_AGENT}\","
QUERY="{\"cmd\": \"request.get\",\"url\":\"${YGG_URL}/\",${UAGENT}\"maxTimeout\": ${TIMEOUT},\"session\": \"${SESSION_ID}\""
[ -n "${HEADERS}" ] && QUERY="${QUERY},${HEADERS}"
QUERY="${QUERY}}"
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

#cat "${TMP}" | awk '{print "[DEBUG_REFERER] "$0}' >&2

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
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
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

unset DEBUG
#DEBUG="true"

## DEBUG First GET
[ -n "${DEBUG}" ] && echo "[DEBUG] Response : " >&2
[ -n "${DEBUG}" ] && cat "${TMP}" | python -m json.tool >&2

#################################################################################################################
# Creating login request
#cat > "${TMP_JSON}" <<- EOF
#{
#          "cmd": "request.post",
#          "url":"${YGG_URL}/user/login",
#          ${UAGENT}
#          "maxTimeout": ${TIMEOUT},
#          "session":"${SESSION_ID}",
#          "postData": "id=${YGG_LOGIN}&pass=${YGG_PASS}&submit=&ci_csrf_token=",
#          "headers": {
#            "Content-Type": "application/x-www-form-urlencoded",
#                "referer": "${REFERER}",
#                "X-Requested-With": "XMLHttpRequest"
#          }
#}
#EOF

#BOUNDARIE=$(od -An -N12 -i /dev/random | awk '{for(i=1;i<=NF;i++){gsub("-","",$i);printf("%i",$i)}}END{print ""}' | cut -c1-30)
#
#POST_DATA="-----------------------------${BOUNDARIE}
#Content-Disposition: form-data; name=\"id\"
#
#${YGG_LOGIN}
#-----------------------------${BOUNDARIE}
#Content-Disposition: form-data; name=\"pass\"
#
#${YGG_PASS}
#-----------------------------${BOUNDARIE}
#Content-Disposition: form-data; name=\"ci_csrf_token\"
#
#
#-----------------------------${BOUNDARIE}"
#POST_JSON_DATA=$(printf %s "${POST_DATA}" |jq -sRr @json | sed 's/^"//' | sed 's/"$//')


POST_URL_DATA="id=${YGG_LOGIN}&pass=${YGG_PASSWORD}&ci_csrf_token="

POST_DATA=$(printf "%s" "${POST_URL_DATA}" | jq -sRr @json | sed 's/^"//' | sed 's/"$//')
#printf "%s\n" "${POST_JSON_DATA}" | awk '{print "[POST_JSON_DATA] "$0}'

#cat > "${TMP_JSON}" <<- EOF
#{
#          "cmd": "request.post",
#          "url":"${YGG_URL}/user/login",
#          ${UAGENT}
#          "maxTimeout": ${TIMEOUT},
#          "session":"${SESSION_ID}",
#          "postData": "${POST_JSON_DATA}",
#          "headers": {
#            "Content-Type": "multipart/form-data; boundary=---------------------------${BOUNDARIE}",
#                "Referer": "${REFERER}",
#               "Origin": "${REFERER}",
#               "Sec-Fetch-Dest": "empty",
#               "Sec-Fetch-Mode": "cors",
#               "Sec-Fetch-Site": "same-origin",
#                "X-Requested-With": "XMLHttpRequest"
#          }
#}
#EOF
cat > "${TMP_JSON}" <<- EOF
{
          "cmd": "request.post",
          "url":"${YGG_URL}/user/login",
          ${UAGENT}
          "maxTimeout": ${TIMEOUT},
          "session":"${SESSION_ID}",
          "postData": "${POST_DATA}"
}
EOF
RC=$?

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to create YGG query" >&2
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
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
#cat "${TMP_JSON}" >&2
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "@${TMP_JSON}" > "${TMP}"
RC=$?

ERROR=`cat "${TMP}" | jq -r '.error'`
[ "${ERROR}" = "null" ] && unset ERROR
[ -n "${ERROR}" ] && RC=99

if [ ${RC} -ne 0 ];then
        echo "[ERROR] YGG Login Failed" >&2
        echo "Query:" >&2
        cat "${TMP_JSON}" >&2

        echo "Response:" >&2
        cat "${TMP}" >&2
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
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

unset STATUS MSG HTTP_CODE

#cat "${TMP}" | jq -r '.solution.response' >&2
# On recupere le code JSON qui est intégré dans une balise "<pre>" de la reponse
JSON_RESPONSE=`cat "${TMP}" | jq -r '.solution.response' | sed 's/.*<pre>//' | sed 's|</pre>.*||'`

# Quand tout c'est bien passé, ca renvoie un body vide
if [ "${JSON_RESPONSE}" = "<html><head></head><body></body></html>" ];then
        unset JSON_RESPONSE
else
        JSON_RESPONSE=$(echo "${JSON_RESPONSE}" | sed 's/.*pre-wrap;">//')
fi

if [ -n "${JSON_RESPONSE}" ] && ! echo "${JSON_RESPONSE}" | jq '.' > /dev/null 2>&1;then
        echo "[ERROR] Le retour json intégré est invalide" >&2
        #printf "${JSON_RESPONSE}" | awk '{print "[DEBUG] "$0}' >&2
        STATUS="ERROR"
fi

RESULT=`echo "${JSON_RESPONSE}" | jq -r '.result'`
if [ "${RESULT}" = "false" ];then
        MSG=`echo "${JSON_RESPONSE}" | jq -r '.message'`
        echo "[ERROR] Login Failed !" >&2
        echo "[ERROR] '${MSG}'" >&2
        cat "${TMP_JSON}" | awk '{print "[DEBUG] "$0}' >&2
        STATUS="ERROR"
fi


#################################################################################################################
# Login verification
[ -z "${STATUS}" ] && STATUS=`cat "${TMP}" | jq '.status' 2>/dev/null | tr -d '"'`
[ -z "${MSG}"    ] && MSG=`cat "${TMP}" | jq '.message' 2>/dev/null | tr -d '"'`
HTTP_CODE=`cat "${TMP}" | jq '.solution.status' 2>/dev/null | tr -d '"'`

if [ "${STATUS}" != "ok" ] || [ "${HTTP_CODE}" != "200" ];then
        echo "[ERROR] YGG login failed. ReturnCode checking is KO" >&2
        echo "[${STATUS}] ${MSG}" >&2
        #echo "Query:" >&2
        #cat "${TMP_JSON}" >&2  # Will show your password !

        #echo "Response:" >&2
        #cat "${TMP}" >&2
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
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
        echo "[INFO] Login ygg OK" >&2
        #cat "${TMP}" | jq -r '.solution.response' | awk '{print "[DEBUG_RESPONSE] "$0}' >&2
fi

unset DEBUG
#DEBUG="true"

## DEBUG DU LOGIN
[ -n "${DEBUG}" ] && echo "[DEBUG] Query : " >&2
[ -n "${DEBUG}" ] && cat "${TMP_JSON}"  >&2
[ -n "${DEBUG}" ] && echo "[DEBUG] Response : " >&2
[ -n "${DEBUG}" ] && cat "${TMP}" | python -m json.tool >&2

#################################################################################################################
# Retrieve Ratio
echo "[INFO] GET Ratio..." >&2
HEADERS="\"headers\": {\"Accept\": \"application/json, text/javascript, */*; q=0.01\", \"Content-type\": \"application/json; charset=UTF-8\", \"X-Requested-With\": \"XMLHttpRequest\", \"Referer\": \"${REFERER}\"}"
QUERY="{\"cmd\": \"request.get\",\"url\":\"${YGG_URL}/user/ajax_usermenu\",${UAGENT}\"maxTimeout\": ${TIMEOUT},\"session\":\"${SESSION_ID}\",${HEADERS}}"
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${QUERY}" | python -m json.tool  > "${TMP}" 2>&1
RC=$?

RETURN_URL=$(cat "${TMP}" | jq -r '.solution.url')
if echo "${RETURN_URL}" | grep -q 'error?http_code=error?http_code=[45][0-9]*$';then
        RC=50
fi

unset STATUS
if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to get Ratio" >&2
        #curl -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${QUERY}"
        cat "${TMP}" >&2

        # Nettoyage session flaresolverr
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
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
        exit 55
else
        true
        #cat "${TMP}" | awk '{print "[DEBGU_RATIO] "$0}'
fi

unset DEBUG
#DEBUG="true"

## DEBUG DU RATIO
[ -n "${DEBUG}" ] && echo "[DEBUG] Query : " >&2
[ -n "${DEBUG}" ] && echo "${QUERY}" | python -m json.tool >&2
[ -n "${DEBUG}" ] && echo "[DEBUG] Response : " >&2
[ -n "${DEBUG}" ] && cat "${TMP}" | python -m json.tool  >&2

[ -z "${MESSAGE}" ] && MESSAGE=`cat "${TMP}" | jq -r ".message" `
[ -z "${STATUS}"  ] && STATUS=`cat "${TMP}" | jq -r ".status"`
RESPONSE=`cat "${TMP}" | jq -r ".solution.response"`
[ "${RESPONSE}" = "null" ] && unset Response

if [ "${STATUS}" != "ok" ];then
        MSG=`cat "${TMP}" | jq ".message" | tr -d '"'`
        if echo "${RESPONSE}" | grep "Connection requise pour " > /dev/null;then
                MSG="Need to be connect to do this action"
        fi
        echo "[ERROR] Unable to get ratio info" >&2
        echo "[${STATUS}] ${MSG}" >&2

        # Nettoyage session flaresolverr
        curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
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
        exit 57
fi


#################################################################################################################
# FlareSolvrr session cleanup
echo "[INFO] Cleaning session" >&2
curl -s -S -L -X POST "${FLARESOLVR_URL}/v1" -H 'Content-Type: application/json' -d "${DESTROY_JSON}" | python -m json.tool > "${TMP}"
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
#printf "%s\n" "${RESPONSE}" | awk '{print "[REPONSE] "$0}'

if printf "%s\n" "${RESPONSE}" | grep -q "Se connecter";then
        echo "[ERROR] Unable to connect to Ygg" >&2
        RC=98
else
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
        RATIO=`cat "${TMP}" | xmllint --xpath '/ul/li[2]/a/strong' - | sed 's/.* : //' | sed 's/ <.*//'`
fi

[ -z "${DOWNLOAD}" ] && DOWNLOAD="null"
[ -z "${UPLOAD}"   ] && UPLOAD="null"
[ -z "${RATIO}"    ] && RATIO="null"

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
if [ -n "${MQTT_USERNAME}" ];then

        mosquitto_pub -h "${MQTT_HOST}" -p "${MQTT_PORT}" -u "${MQTT_USERNAME}" -P "${MQTT_PASSWORD}" -m "${JSON_DATA}" -t "${MQTT_TOPIC}"
        RC=$?
else
        mosquitto_pub -h "${MQTT_HOST}" -p "${MQTT_PORT}" -m "${JSON_DATA}" -t "${MQTT_TOPIC}"
        RC=$?
fi

if [ ${RC} -ne 0 ];then
        echo "[ERROR] Unable to push message in MQTT" >&2
        exit 100
fi

echo "[INFO] Infos successfuly uploaded to MQTT"