#!/bin/bash

# ==================================================
# STAGING HOSTS TESTER v2
# ==================================================

# ===== Colors =====
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
RESET="\e[0m"

# ===== Root Check =====
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Run as root (sudo)${RESET}"
    exit 1
fi

HOSTS_FILE="/etc/hosts"
TAG="# STAGING_TEMP_ENTRY"

# ==================================================
# CLEANUP (safe + precise)
# ==================================================
cleanup() {
    grep -v "$TAG" "$HOSTS_FILE" > /tmp/hosts.tmp && mv /tmp/hosts.tmp "$HOSTS_FILE"
}

trap cleanup EXIT INT TERM

# ==================================================
# VALIDATORS (robust)
# ==================================================
validate_ip() {
    local ip=$(echo "$1" | tr -d '[:space:]')
    [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

validate_domain() {
    local domain=$(echo "$1" | tr -d '[:space:]')
    [[ $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# ==================================================
# INPUT SAFE LOOP (IP)
# ==================================================
attempt=0
while true; do
    read -p "IP: " ip
    ip=$(echo "$ip" | tr -d '[:space:]')

    ((attempt++))

    if validate_ip "$ip"; then
        break
    fi

    echo -e "${RED}Invalid IP format!${RESET}"

    if [[ $attempt -ge 3 ]]; then
        echo -e "${RED}Too many invalid attempts${RESET}"
        exit 1
    fi
done

# reset attempt
attempt=0

# ==================================================
# INPUT SAFE LOOP (DOMAIN)
# ==================================================
while true; do
    read -p "Domain: " domain
    domain=$(echo "$domain" | tr -d '[:space:]')

    ((attempt++))

    if validate_domain "$domain"; then
        break
    fi

    echo -e "${RED}Invalid domain format!${RESET}"

    if [[ $attempt -ge 3 ]]; then
        echo -e "${RED}Too many invalid attempts${RESET}"
        exit 1
    fi
done

# ==================================================
# HOSTS SETUP (safe + no duplicates)
# ==================================================
cleanup
echo "$ip $domain www.$domain $TAG" >> "$HOSTS_FILE"
echo -e "${GREEN}[+] Hosts updated${RESET}"

# ==================================================
# CURL TESTS (correct + timeout safe)
# ==================================================

HTTP_URL="http://$domain"
HTTPS_URL="https://$domain"

echo ""
echo -e "${BLUE}[+] Testing HTTP...${RESET}"
http_code=$(curl -o /dev/null -s -m 5 -w "%{http_code}" \
    --resolve $domain:80:$ip $HTTP_URL)

echo -e "${YELLOW}HTTP code: $http_code${RESET}"

echo -e "${BLUE}[+] Testing HTTPS...${RESET}"
https_code=$(curl -o /dev/null -s -m 5 -w "%{http_code}" \
    --resolve $domain:443:$ip $HTTPS_URL)

https_insecure=$(curl -o /dev/null -s -k -m 5 -w "%{http_code}" \
    --resolve $domain:443:$ip $HTTPS_URL)

echo -e "${YELLOW}HTTPS strict: $https_code${RESET}"
echo -e "${YELLOW}HTTPS insecure: $https_insecure${RESET}"

# ==================================================
# SSL DEBUG (important fix)
# ==================================================
echo ""
echo -e "${CYAN}[SSL DEBUG]${RESET}"
ssl_debug=$(curl -Iv --resolve $domain:443:$ip https://$domain 2>&1 | tail -n 8)
echo "$ssl_debug"

# ==================================================
# DECISION ENGINE (improved logic)
# ==================================================
USE_URL="$HTTP_URL"
BROWSER="elinks"
REASON=""

if [[ "$https_code" != "000" && "$https_code" -lt 500 ]]; then
    USE_URL="$HTTPS_URL"
    REASON="SSL OK"
elif [[ "$https_insecure" != "000" && "$https_insecure" -lt 500 ]]; then
    USE_URL="$HTTP_URL"
    REASON="SSL issue → fallback HTTP"
else
    USE_URL="$HTTP_URL"
    BROWSER="w3m"
    REASON="HTTPS failed → fallback w3m"
fi

# ==================================================
# OUTPUT RESULT
# ==================================================
echo ""
echo -e "${CYAN}============================${RESET}"
echo -e "${CYAN}Decision Engine${RESET}"
echo -e "${CYAN}============================${RESET}"

echo -e "URL     : ${GREEN}$USE_URL${RESET}"
echo -e "Browser : ${GREEN}$BROWSER${RESET}"
echo -e "Reason  : ${YELLOW}$REASON${RESET}"

# ==================================================
# OPEN BROWSER
# ==================================================
read -p "Press Enter to open..."

if [[ "$BROWSER" == "elinks" ]]; then
    elinks "$USE_URL"
else
    w3m "$USE_URL"
fi

# ==================================================
# CLEANUP AFTER RUN
# ==================================================
cleanup
echo -e "${GREEN}[+] Hosts entry removed${RESET}"
