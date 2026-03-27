#!/bin/bash


DNS_TIMEOUT=3
MAX_RETRY=3
CONN_TIMEOUT=5
MAX_TIME=8

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
RESET="\e[0m"

[[ $EUID -ne 0 ]] && { echo -e "${RED}[ERROR] Run as root${RESET}"; exit 1; }

HOSTS_FILE="/etc/hosts"
TAG="# STAGING_TEMP_ENTRY"

LOCK_FILE="/tmp/staging-hosts.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || { echo -e "${RED}[ERROR] Already running${RESET}"; exit 1; }

cleanup() {
    sed -i "/$TAG/d" "$HOSTS_FILE"
}
trap cleanup EXIT INT TERM


# VALIDATION

validate_ip() {
    [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r o1 o2 o3 o4 <<< "$1"
    for o in $o1 $o2 $o3 $o4; do
        ((o < 0 || o > 255)) && return 1
    done
    return 0
}

validate_domain() {
    [[ "$1" =~ ^([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$ ]]
}

sanitize_domain() {
    d="$1"
    d="${d#*://}"
    d="${d%%/*}"
    d="${d%%:*}"
    d="${d#www.}"
    d="${d//[[:space:]]/}"
    echo "$d"
}


# INPUT IP 

attempt=1
while (( attempt <= MAX_RETRY )); do
    read -p "Target IP: " ip
    ip=$(echo "$ip" | xargs)

    if validate_ip "$ip"; then
        break
    fi

    echo -e "${RED}Invalid IP ($attempt/$MAX_RETRY)${RESET}"
    ((attempt++))

    if (( attempt > MAX_RETRY )); then
        echo -e "${RED}[FATAL] Too many invalid IP attempts${RESET}"
        exit 1
    fi
done


# INPUT DOMAIN 

attempt=1
while (( attempt <= MAX_RETRY )); do
    read -p "Target Domain: " raw
    domain=$(sanitize_domain "$raw")

    if validate_domain "$domain"; then
        break
    fi

    echo -e "${RED}Invalid Domain ($attempt/$MAX_RETRY)${RESET}"
    ((attempt++))

    if (( attempt > MAX_RETRY )); then
        echo -e "${RED}[FATAL] Too many invalid domain attempts${RESET}"
        exit 1
    fi
done


# DNS CHECK

echo -e "\n${CYAN}[1/4] DNS${RESET}"
A_REC=$(timeout $DNS_TIMEOUT dig +short A "$domain" | tail -n1)
echo -e "Public IP: ${YELLOW}${A_REC:-None}${RESET}"


# HOSTS UPDATE

echo -e "${CYAN}[2/4] Updating Hosts${RESET}"
cleanup
echo -e "$ip\t$domain\twww.$domain\t$TAG" >> "$HOSTS_FILE"


# CURL TEST 

echo -e "${CYAN}[3/4] CURL TEST${RESET}"

echo -e "\n${BLUE}HTTP:${RESET}"
curl -s -o /dev/null \
    --connect-timeout $CONN_TIMEOUT \
    --max-time $MAX_TIME \
    -w "Code: %{http_code} | Time: %{time_total}s | IP: %{remote_ip}\n" \
    --resolve "$domain:80:$ip" "http://$domain"

echo -e "${BLUE}HTTPS (strict):${RESET}"
https_code=$(curl -s -o /dev/null \
    --connect-timeout $CONN_TIMEOUT \
    --max-time $MAX_TIME \
    -w "%{http_code}" \
    --resolve "$domain:443:$ip" "https://$domain" 2>/dev/null)

echo -e "Code: ${https_code:-TIMEOUT}"

echo -e "${BLUE}HTTPS (insecure):${RESET}"
https_insecure=$(curl -s -o /dev/null -k \
    --connect-timeout $CONN_TIMEOUT \
    --max-time $MAX_TIME \
    -w "%{http_code}" \
    --resolve "$domain:443:$ip" "https://$domain" 2>/dev/null)

echo -e "Code: ${https_insecure:-TIMEOUT}"


# DECISION ENGINE

USE_URL="http://$domain"
BROWSER="w3m"
REASON=""

if [[ "$https_code" != "000" && "$https_code" != "" ]]; then
    USE_URL="https://$domain"
    BROWSER="elinks"
    REASON="SSL VALID"
elif [[ "$https_insecure" != "000" && "$https_insecure" != "" ]]; then
    USE_URL="http://$domain"
    BROWSER="elinks"
    REASON="SSL BROKEN → fallback HTTP"
else
    USE_URL="http://$domain"
    BROWSER="w3m"
    REASON="NO SSL / TIMEOUT"
fi


# RESULT

echo ""
echo -e "${CYAN}=== RESULT ===${RESET}"
echo -e "URL: ${GREEN}$USE_URL${RESET}"
echo -e "Browser: ${GREEN}$BROWSER${RESET}"
echo -e "Reason: ${YELLOW}$REASON${RESET}"

read -p "Press Enter to launch..."


# LAUNCH

if command -v "$BROWSER" >/dev/null; then
    $BROWSER "$USE_URL"
else
    echo -e "${RED}[Fallback curl]${RESET}"
    curl -L -k \
        --connect-timeout $CONN_TIMEOUT \
        --max-time $MAX_TIME \
        --resolve "$domain:443:$ip" "$USE_URL"
fi


# CLEANUP

cleanup
echo -e "\n${GREEN}[DONE] Hosts cleaned${RESET}"
