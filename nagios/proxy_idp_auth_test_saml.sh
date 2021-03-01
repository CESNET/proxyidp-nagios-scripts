#!/bin/bash

# This script is used make a full roundtrip login test to SAML SP
# Exit statuses indicate problem and are suitable for usage in Nagios.
# @author Pavel Vyskocil <Pavel.Vyskocil@cesnet.cz>

DIR="${0%/*}"
source "${DIR}/proxy_idp_auth_test_config.sh"

CACHE_FILE=${DIR}/proxy_idp_auth_test_saml.cache

if [[ $1 == "-f" ]]; then
    FORCE=0
else
    FORCE=1
fi

if [[ -f "$CACHE_FILE" ]]; then
  CACHE_LAST_MODIFIED=$(($(date +%s) - $(date +%s -r ${CACHE_FILE})))
  REGEX_CHECK=$(grep -c '\d proxy_idp_auth_test_saml.sh.*muni_login_time.*cesnet_login_time.*MUNI STATUS.*CESNET STATUS' ${CACHE_FILE})

  if [[ ${CACHE_LAST_MODIFIED} -le ${CACHE_TIME} && $(wc -l <${CACHE_FILE}) -eq 1 && ${REGEX_CHECK} -eq 0 && ${FORCE} -ne 0 ]]; then
    echo "$(<${CACHE_FILE})"
    exit 0
  fi
fi

BASENAME=$(basename "$0")
WARNING_TIME=${SAML_WARNING_TIME}

SCRIPT_DIR="${DIR}/proxy_idp_auth_test_script"

AAI_LOGIN_CMD="$SCRIPT_DIR/saml_auth_test_aai.sh ${AAI_SAML_TEST_SITE} ${AAI_LOGIN_SITE} ${AAI_LOGIN} ${AAI_PASSWORD} ${PROXY_DOMAIN_NAME}"
MUNI_LOGIN_CMD="$SCRIPT_DIR/saml_auth_test_muni.sh ${MUNI_SAML_TEST_SITE} ${MUNI_LOGIN_SITE} ${MUNI_LOGIN} ${MUNI_PASSWORD} ${PROXY_DOMAIN_NAME}"
CESNET_LOGIN_CMD="$SCRIPT_DIR/saml_auth_test_cesnet.sh ${CESNET_SAML_TEST_SITE} ${CESNET_LOGIN_SITE} ${CESNET_LOGIN} ${CESNET_PASSWORD} ${PROXY_DOMAIN_NAME}"

# Test sign in with AAI Playground IdP
START_TIME=$(date +%s%N)
AAI_RESULT=$(timeout ${TIMEOUT_TIME} ${AAI_LOGIN_CMD})
AAI_RC=$?
END_TIME=$(date +%s%N)

if [ ${AAI_RC} -gt 2 ]; then
  AAI_RC=2
  AAI_RESULT="Login with AAI account timeouted after ${TIMEOUT_TIME}s!"
fi
AAI_TOTAL_TIME=$(expr ${END_TIME} - ${START_TIME})
AAI_LOGIN_TIME=$(echo "scale=4;${AAI_TOTAL_TIME} / 1000000000" | bc -l)

# Signing in with AAI account was successful. Returning OK.
if [ ${AAI_RC} -eq 0 ]; then
    if [ ${AAI_TOTAL_TIME} -gt $(( WARNING_TIME * 1000000000 )) ];then
        STATUS=1
        STATUS_TXT="Successful login, but was too long(More than ${WARNING_TIME}s)!"
    else
        STATUS=0
        STATUS_TXT="Successful login!"
    fi

    RESULT="${STATUS} ${BASENAME}-${INSTANCE_NAME} aai_login_time=${AAI_LOGIN_TIME}|muni_login_time=0|cesnet_login_time=0 ${STATUS_TXT} [AAI STATUS - ${AAI_RESULT}(${AAI_LOGIN_TIME}s);MUNI STATUS - Not tried; CESNET STATUS - Not tried]"
    echo ${RESULT}
    echo ${RESULT} > ${DIR}/proxy_idp_auth_test_saml.cache
    exit 0
fi

# Test sign in with MUNI IdP
START_TIME=$(date +%s%N)
MUNI_RESULT=$(timeout ${TIMEOUT_TIME} ${MUNI_LOGIN_CMD})
MUNI_RC=$?
END_TIME=$(date +%s%N)
if [ ${MUNI_RC} -gt 2 ]; then
  MUNI_RC=2
  MUNI_RESULT="Login with MUNI account timeouted after ${TIMEOUT_TIME}s!"
fi
MUNI_TOTAL_TIME=$(expr ${END_TIME} - ${START_TIME})
MUNI_LOGIN_TIME=$(echo "scale=4;${MUNI_TOTAL_TIME} / 1000000000" | bc -l)

# Signing in with MUNI account was successful. Returning OK.
if [ ${MUNI_RC} -eq 0 ]; then
    if [ ${MUNI_TOTAL_TIME} -gt $(( WARNING_TIME * 1000000000 )) ];then
        STATUS=1
        STATUS_TXT="Successful login, but was too long(More than ${WARNING_TIME}s)!"
    else
        STATUS=0
        STATUS_TXT="Successful login!"
    fi

    RESULT="${STATUS} ${BASENAME}-${INSTANCE_NAME} aai_login_time=${AAI_LOGIN_TIME}|muni_login_time=${MUNI_LOGIN_TIME}|cesnet_login_time=0 ${STATUS_TXT} [AAI STATUS - ${AAI_RESULT}(${AAI_LOGIN_TIME}s);MUNI STATUS - ${MUNI_RESULT}(${MUNI_LOGIN_TIME}s); CESNET STATUS - Not tried]"
    echo ${RESULT}
    echo ${RESULT} > ${DIR}/proxy_idp_auth_test_saml.cache
    exit 0
fi


# Test sign in with CESNET IdP
START_TIME=$(date +%s%N)
CESNET_RESULT=$(timeout ${TIMEOUT_TIME} ${CESNET_LOGIN_CMD})
CESNET_RC=$?
END_TIME=$(date +%s%N)

if [ ${CESNET_RC} -gt 2 ]; then
  CESNET_RC=2
  CESNET_RESULT="Login with CESNET account timeouted after ${TIMEOUT_TIME}s!"
fi

CESNET_TOTAL_TIME=$(expr ${END_TIME} - ${START_TIME})
CESNET_LOGIN_TIME=$(echo "scale=4;${CESNET_TOTAL_TIME} / 1000000000" | bc -l)


# Signing in with CESNET account was successful. Returning OK.
if [ ${CESNET_RC} -eq 0 ]; then
    if [ ${CESNET_TOTAL_TIME} -gt $(( WARNING_TIME * 1000000000 )) ];then
        STATUS=1
        STATUS_TXT="Successful login, but was too long(More than ${WARNING_TIME}s)!"
    else
        STATUS=0
        STATUS_TXT="Successful login!"
    fi
else
    STATUS=2
    STATUS_TXT="ERROR!"
fi

RESULT="${STATUS} ${BASENAME}-${INSTANCE_NAME} aai_login_time=${AAI_LOGIN_TIME}|muni_login_time=${MUNI_LOGIN_TIME}|cesnet_login_time=${CESNET_LOGIN_TIME} ${STATUS_TXT} [AAI STATUS - ${AAI_RESULT}(${AAI_LOGIN_TIME}s);MUNI STATUS - ${MUNI_RESULT}(${MUNI_LOGIN_TIME}s); CESNET STATUS - ${CESNET_RESULT}(${CESNET_LOGIN_TIME}s)]"

echo ${RESULT}
echo ${RESULT} > ${DIR}/proxy_idp_auth_test_saml.cache
exit 0
