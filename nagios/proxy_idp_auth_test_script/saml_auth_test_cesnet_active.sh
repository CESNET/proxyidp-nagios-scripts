#!/bin/bash

# This script is used make a full roundtrip login test to SAML SP via CESNET account
# Exit statuses indicate problem and are suitable for usage in Nagios.
# @author Pavel Vyskocil <Pavel.Vyskocil@cesnet.cz>

end()
{
  LOGIN_STATUS=$1
  LOGIN_STATUS_TXT=$2

  # Clean up
  rm -f "${COOKIE_FILE}"

  echo "${LOGIN_STATUS_TXT}"
  exit "${LOGIN_STATUS}"
}

BASENAME=$(basename "$0")


TEST_SITE=$1
LOGIN_SITE=$2
LOGIN=$3
PASSWORD=$4

COOKIE_FILE=$(mktemp /tmp/"${BASENAME}".XXXXXX) || exit 3

# REQUEST #1: fetch URL for authentication page
HTML=$(curl -L -s -c "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}'  "${TEST_SITE}") || (end 2 "Failed to fetch URL: ${TEST_SITE}")

# Parse HTML to get the URL where to POST LOGIN (written out by curl itself above)
AUTH_URL=$(echo ${HTML} | sed -e 's/.*LAST_URL:\(.*\)$/\1/')
CSRF_TOKEN=$(echo ${HTML} | sed -e 's/.*hidden[^>]*csrf_token[^>]*value=[\"'\'']\([^\"'\'']*\)[\"'\''].*/\1/')

# We should be redirected
if [[ ${AUTH_URL} == "${TEST_SITE}" ]]; then
    end 2 "No redirection to: ${LOGIN_SITE}."
    return
fi

# REQUEST #2: log in
HTML=$(curl -L -s -c "${COOKIE_FILE}" -b "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}' -d "j_username=$LOGIN" -d  "j_password=$PASSWORD" -d "_eventId_proceed=" -d "csrf_token=$CSRF_TOKEN" --resolve "${DOMAIN_NAME}"':443:'${IP} "${AUTH_URL}") || (end 2 "Failed to fetch URL: ${AUTH_URL}")

LAST_URL=$(echo ${HTML} | sed -e 's/.*LAST_URL:\(.*\)$/\1/')

# We should be successfully logged in
if [[ ${LAST_URL} != "${AUTH_URL}" ]]; then
    end 2 "Invalid credentials."
fi

# We do not support JS, so parse HTML for SAML endpoint and response
PROXY_ENDPOINT=$(echo ${HTML} | sed -e 's/.*form[^>]*action=[\"'\'']\([^\"'\'']*\)[\"'\''].*method[^>].*/\1/' | php -R 'echo HTML_entity_decode($argn);')
PROXY_RESPONSE=$(echo ${HTML} | sed -e 's/.*hidden[^>]*SAMLResponse[^>]*value=[\"'\'']\([^\"'\'']*\)[\"'\''].*/\1/')

# REQUEST #3: post the SAMLResponse to proxy
HTML=$(curl -L -s -c "${COOKIE_FILE}" -b "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}' \
  --data-urlencode "SAMLResponse=${PROXY_RESPONSE}"  "${PROXY_ENDPOINT}") || (end 2 "Failed to fetch URL: ${PROXY_ENDPOINT}")

if [[ $HTML == *errorreport.php* ]]; then
    MSG=$(echo ${HTML} | sed -e 's/.*<h1>.*<\/i>\s\(.*\)\s<\/h1>.*id="content">\s<p>\s\(.*\)<a.*moreInfo.*/\1 - \2/g')
    end 2 "Get error: ${MSG} "
fi

# We do not support JS, so parse HTML for SAML endpoint and response
SP_ENDPOINT=$(echo ${HTML} | sed -e 's/.*form[^>]*action=[\"'\'']\([^\"'\'']*\)[\"'\''].*method[^>].*/\1/')
SP_RESPONSE=$(echo ${HTML} | sed -e 's/.*hidden[^>]*SAMLResponse[^>]*value=[\"'\'']\([^\"'\'']*\)[\"'\''].*/\1/')

# REQUEST #4: post the SAMLResponse to SP
HTML=$(curl -L -s -c "${COOKIE_FILE}" -b "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}' \
  --data-urlencode "SAMLResponse=${SP_RESPONSE}"  "${SP_ENDPOINT}") || (end 2 "Failed to fetch URL: ${SP_ENDPOINT}")

LAST_URL=$(echo ${HTML} | sed -e 's/.*LAST_URL:\(.*\)$/\1/')

if [[ ${LAST_URL} ==  "${TEST_SITE}" ]]; then
    RESULT=$(echo ${HTML} | sed -e 's/.*<body>\s*Result-\(.*\)<.*$/\1/')
    if [[ "${RESULT}" == "OK " ]]; then
        end 0 "Successful login"
    else
        end 2 "Bad result: ${RESULT}."
    fi

else
    end 2 "Not redirected back to: ${TEST_SITE}."
fi
