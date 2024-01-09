#!/bin/sh

# Check if config file was provided
if [ $# -eq 0 ]; then
    echo "No config file provided"
    exit 1
fi

# Source the config file
source $1

# Print the configuration values
echo "Configuration values:"
echo "PUBLIC_IP_CHECK_SERVICE: $PUBLIC_IP_CHECK_SERVICE"
echo "DOMAIN_NAME: $DOMAIN_NAME"
echo "DOMAIN_NAME_RECORD_ID: $DOMAIN_NAME_RECORD_ID"
echo "========================"

# Check if all required configs were provided
if [ -z "${PUBLIC_IP_CHECK_SERVICE}" ] || 
    [ -z "${DOMAIN_NAME}" ] || 
    [ -z "${DIGITAL_OCEAN_API_TOKEN}" ] ||
    [ -z "${DOMAIN_NAME_RECORD_ID}" ]; then
    echo "All required configuration values were not provided"
    echo "The following values are required:"
    echo "PUBLIC_IP_CHECK_SERVICE"
    echo "DOMAIN_NAME"
    echo "DIGITAL_OCEAN_API_TOKEN"
    echo "DOMAIN_NAME_RECORD_ID"
    exit 1
fi

# Check if the file exists
if [ -f public_ip.txt ]; then
    echo "Reading public IP from file"
    public_ip=$(cat public_ip.txt)
else
    echo "Getting public IP from service"
    public_ip=$(curl -s $PUBLIC_IP_CHECK_SERVICE)
    echo "$public_ip" > public_ip.txt
fi

# Get the IP address of the domain name
dns_ip_address=$(dig +short $DOMAIN_NAME)



function digitalocean_dns_update()
{
    >&2 echo updating dns ip to $1
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PATCH \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DIGITAL_OCEAN_API_TOKEN" \
    "https://api.digitalocean.com/v2/domains/$DOMAIN_NAME/records/$DOMAIN_RECORD_ID" \
    --data '{
        "data": "'$1'"
        }')
    if [ "$http_code" == "200" ]; then
        echo "$(date): DNS IP address updated successfully: $public_ip" >> log.txt
        echo "$public_ip" > public_ip.txt
    else
        dnsfailure_msg="DNS IP address update failed: HTTP code: $http_code"
        echo "$(date): $dnsfailure_msg" >> log.txt
        echo $dnsfailure_msg
        exit 1
    fi
}

# Check if the IP addresses match
if [ "$dns_ip_address" == "$public_ip" ]; then
    echo "$(date): IP addresses match...skipping update"  >> log.txt
    exit 0
else
    echo "$(date): DNS IP address ($dns_ip_address) does not match public IP ($public_ip)" >> log.txt
    echo "Updating DNS IP address"
    digitalocean_dns_update $public_ip
    exit 1
fi

# Keep only the last 100 lines in the log file
tail -n 100 log.txt > temp.txt && mv temp.txt log.txt
