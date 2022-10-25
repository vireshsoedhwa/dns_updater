#!/bin/sh

set -e

if [[ -z "${CURL_ENDPOINT_PRIMARY}" ]]; then
  exit 1
fi
if [[ -z "${CURL_ENDPOINT_SECONDARY}" ]]; then
  exit 1
fi
if [[ -z "${DIG_HOST}" ]]; then
  exit 1
fi
if [[ -z "${DNS_TOKEN}" ]]; then
  exit 1
fi
if [[ -z "${DOMAIN_NAME}" ]]; then
  exit 1
fi
if [[ -z "${DOMAIN_RECORD_ID}" ]]; then
  exit 1
fi

echo "`date` [`hostname`] Checking address" >> /log/entries.txt;
>&2 echo "Checking address"
>&2 echo CURL_ENDPOINT_PRIMARY: $CURL_ENDPOINT_PRIMARY
>&2 echo CURL_ENDPOINT_SECONDARY: $CURL_ENDPOINT_SECONDARY
>&2 echo DIG_HOST: $DIG_HOST

curl_result_primary=$(curl -s $CURL_ENDPOINT_PRIMARY)
curl_result_secondary=$(curl -s $CURL_ENDPOINT_SECONDARY)

echo "curl result primary ($curl_result_primary)"
echo "curl result secondary ($curl_result_secondary)"
dig_result=$(dig @8.8.8.8 +short $DIG_HOST)
echo "dig result ($dig_result)"

function validate_ip()
{
    if expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' >/dev/null; then
    for i in 1 2 3 4; do
        if [ $(echo "$1" | cut -d. -f$i) -gt 255 ]; then
            echo "failed ($1)"
            # exit 1
            return 1
        fi
    done
        echo "validated ($1)"
        # exit 0
        return 0
    else
        echo "failed validation ($1)"
        # exit 1
        return 1
    fi
}

function fix_ip()
{
    >&2 echo fixing dns ip to $1
    echo $(curl -s -X PATCH \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DNS_TOKEN" \
    "https://api.digitalocean.com/v2/domains/$DOMAIN_NAME/records/$DOMAIN_RECORD_ID" \
    --data '{
        "data": "'$1'"
        }')
}

if validate_ip $curl_result_primary ; 
then 
    if [ "$dig_result" = "$curl_result_primary" ]; then
        echo "no fixing needed"
        exit 0
    else
        fix_ip $curl_result_primary
        echo "`date` [`hostname`] changed from $dig_result to $curl_result_primary" >> /log/entries.txt;
        exit 1
    fi
else 
    echo "primary curl failed"; 
fi

if validate_ip $curl_result_secondary ; 
then 
    if [ "$dig_result" = "$curl_result_secondary" ]; then
        echo "no fixing needed"
        exit 0
    else
        fix_ip $curl_result_secondary
        echo "`date` [`hostname`] changed from $dig_result to $curl_result_secondary" >> /log/entries.txt;
        exit 1
    fi
else 
    echo "secondary curl failed"; 
fi

# exec "$@"