#!/bin/bash

# This script is used make a full roundtrip login test to SAML SP via OWN Identity provider
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

BASENAME=$(basename $0)

## Get host IP
IP=($(hostname -I))

TEST_SITE=$1
LOGIN_SITE=$2
LOGIN=$3
PASSWORD=$4
DOMAIN_NAME=$5

COOKIE_FILE=$(mktemp /tmp/"${BASENAME}".XXXXXX) || exit 3

# REQUEST #1: fetch URL for authentication page
HTML=$(curl -L -sS -c "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}' --resolve ${DOMAIN_NAME}':443:'${IP} ${TEST_SITE}) || (end 2 "Failed to fetch URL: ${TEST_SITE}")

# Parse HTML to get the URL where to POST LOGIN (written out by curl itself above)
AUTH_URL=$(echo ${HTML} | sed -e 's/.*LAST_URL:\(.*\)$/\1/')
AUTH_STATE=$(echo ${HTML} | sed -e 's/.*hidden[^>]*AuthState[^>]*value=[\"'\'']\([^\"'\'']*\)[\"'\''].*/\1/')

# We should be redirected
if [[ ${AUTH_URL} == "${TEST_SITE}" ]]; then
    end 2 "No redirection to: ${LOGIN_SITE}."
fi

# REQUEST #2: log in
HTML=$(curl -L -s -c "${COOKIE_FILE}" -b "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}' \
-d "username=$LOGIN" -d  "password=$PASSWORD" --data-urlencode "AuthState=${AUTH_STATE}" --resolve ${DOMAIN_NAME}':443:'${IP} ${AUTH_URL}) || (end 2 "Failed to fetch URL: ${AUTH_URL}")

LAST_URL=$(echo ${HTML} | sed -e 's/.*LAST_URL:\(.*\)$/\1/')

# We do not support JS, so parse HTML for SAML endpoint and response
PROXY_ENDPOINT=$(echo ${HTML} | sed -e 's/.*form[^>]*action=[\"'\'']\([^\"'\'']*\)[\"'\''].*method[^>].*/\1/' | php -R 'echo HTML_entity_decode($argn);')
PROXY_RESPONSE=$(echo ${HTML} | sed -e 's/.*hidden[^>]*SAMLResponse[^>]*value=[\"'\'']\([^\"'\'']*\)[\"'\''].*/\1/')

if [[ ${PROXY_ENDPOINT} == "?" ]]; then
    end 2 "Invalid credentials."
fi

# REQUEST #3: post the SAMLResponse to proxy
HTML=$(curl -L -s -c "${COOKIE_FILE}" -b "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}' \
  --data-urlencode "SAMLResponse=${PROXY_RESPONSE}" --resolve "${DOMAIN_NAME}"':443:'${IP} "${PROXY_ENDPOINT}") || (end 2 "Failed to fetch URL: ${PROXY_ENDPOINT}" )

if [[ $HTML == *errorreport.php* ]]; then
    MSG=$(echo ${HTML} | sed -e 's/.*<h1>.*<\/i>\s\(.*\)\s<\/h1>.*id="content">\s<p>\s\(.*\)<a.*moreInfo.*/\1 - \2/g')
    end 2 "Got error: ${MSG} "
fi

# We do not support JS, so parse HTML for SAML endpoint and response
SP_ENDPOINT=$(echo ${HTML} | sed -e 's/.*form[^>]*action=[\"'\'']\([^\"'\'']*\)[\"'\''].*method[^>].*/\1/')
SP_RESPONSE=$(echo ${HTML} | sed -e 's/.*hidden[^>]*SAMLResponse[^>]*value=[\"'\'']\([^\"'\'']*\)[\"'\''].*/\1/')

# REQUEST #4: post the SAMLResponse to SP
HTML=$(curl -L -s -c "${COOKIE_FILE}" -b "${COOKIE_FILE}" -w 'LAST_URL:%{url_effective}' \
  --data-urlencode "SAMLResponse=${SP_RESPONSE}" --resolve "${DOMAIN_NAME}"':443:'${IP} "${SP_ENDPOINT}") || (end 2 "Failed to fetch URL: ${SP_ENDPOINT}" )

LAST_URL=$(echo ${HTML} | sed -e 's/.*LAST_URL:\(.*\)$/\1/')

if [[ ${LAST_URL} ==  "${TEST_SITE}" ]]; then
    RESULT=$(echo ${HTML} | sed -e 's/.*<body>\s*Result-\(.*\)<.*$/\1/')
    if [[ $RESULT == "OK " ]]; then
        end 0 "Successful login"
    else
        end 2 "Bad result: ${RESULT}."
    fi
else
    end 2 "Not redirected back to: ${TEST_SITE}."
fi
