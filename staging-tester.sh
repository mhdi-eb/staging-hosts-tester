#!/bin/bash

# ===== Colors =====
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BLUE="\e[34m"
RESET="\e[0m"

# ===== Root Check =====
[[ $EUID -ne 0 ]] && { echo -e "${RED}[ERROR] Run as root${RESET}"; exit 1; }

HOSTS_FILE="/etc/hosts"
TAG="# STAGING_TEMP_ENTRY"

# ==================================================
# LOCK (prevent concurrent runs)
# ==================================================
LOCK_FILE="/tmp/staging-hosts.lock"
exec 200>$LOCK_FILE
flock -n 200 || { echo -e "${RED}[ERROR] Another instance is running${RESET}"; exit 1; }

# ==================================================
# CLEANUP
# ==================================================
cleanup() {
    grep -v "$TAG" "$HOSTS_FILE" > /tmp/hosts.tmp && mv /tmp/hosts.tmp "$HOSTS_FILE"
}
trap cleanup EXIT INT TERM

# ==================================================
# VALIDATORS
# ==================================================
validate_ip() {
    local ip=$(echo "$1" | tr -d '[:space:]')

    [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
    for o in $o1 $o2 $o3 $o4; do
        ((o < 0 || o > 255)) && return 1
    done

    return 0
}

validate_domain() {
    [[ "$1" =~ ^([a-zA-Z0-9](([a-zA-Z0-9-]*[a-zA-Z0-9])?)\.)+[a-zA-Z]{2,}$ ]]
}

# ==================================================
# SANITIZE INPUT
# ==================================================
sanitize_domain() {
    local d="$1"

    # remove protocol
    d=${d#*://}

    # remove path
    d=${d%%/*}

    # remove port
    d=${d%%:*}

    # remove leading www
    [[ $d == www.* ]] && d=${d#www.}

    # remove wildcard
    [[ $d == \*.* ]] && d=${d#*.}

    # trim spaces
    d=${d//[[:space:]]/}

    echo "$d"
}

# ==================================================
# DNS REPORT (non-blocking)
# ==================================================
dns_report() {
    local d="$1"

    echo -e "${CYAN}[DNS INFO]${RESET}"

    A=$(dig +short A "$d")
    [[ -n "$A" ]] && echo -e "A: ${GREEN}$A${RESET}" || echo -e "A: ${RED}None${RESET}"

    AAAA=$(dig +short AAAA "$d")
    [[ -n "$AAAA" ]] && echo -e "AAAA: ${GREEN}$AAAA${RESET}"

    CNAME=$(dig +short CNAME "$d")
    [[ -n "$CNAME" ]] && echo -e "CNAME: ${GREEN}$CNAME${RESET}"

    NS=$(dig +short NS "$d")
    [[ -n "$NS" ]] && echo -e "NS: ${GREEN}$NS${RESET}"

    if [[ -z "$A" && -z "$AAAA" ]]; then
        echo -e "${YELLOW}[WARN] No A/AAAA record${RESET}"
    else
        echo -e "${GREEN}[OK] DNS looks fine${RESET}"
    fi

    echo ""
}

# ==================================================
# UPDATE HOSTS (safe)
# ==================================================
update_hosts() {
    cleanup
    if ! grep -q "$2" "$HOSTS_FILE"; then
        echo -e "$1\t$2\twww.$2\t$TAG" >> "$HOSTS_FILE"
    fi
}

# ==================================================
# INPUT (IP)
# ==================================================
while true; do
    read -p "IP: " ip
    ip=$(echo "$ip" | tr -d '[:space:]')

    if validate_ip "$ip"; then
        break
    else
        echo -e "${RED}Invalid IP format!${RESET}"
    fi
done

# ==================================================
# INPUT (DOMAIN)
# ==================================================
while true; do
    read -p "Domain: " domain

    domain=$(sanitize_domain "$domain")

    if validate_domain "$domain"; then
        break
    else
        echo -e "${RED}Invalid domain format!${RESET}"
    fi
done

# ==================================================
# DNS CHECK
# ==================================================
dns_report "$domain"

# ==================================================
# HOSTS SETUP
# ==================================================
update_hosts "$ip" "$domain"
echo -e "${GREEN}[+] Hosts updated${RESET}"

HTTP_URL="http://$domain"
HTTPS_URL="https://$domain"

# ==================================================
# CURL TESTS
# ==================================================
echo -e "${BLUE}[+] Testing HTTP...${RESET}"
http_code=$(curl -o /dev/null -s -m 5 -w "%{http_code}" \
    --resolve $domain:80:$ip $HTTP_URL)

echo -e "${YELLOW}HTTP: $http_code${RESET}"

echo -e "${BLUE}[+] Testing HTTPS...${RESET}"
https_code=$(curl -o /dev/null -s -m 5 -w "%{http_code}" \
    --resolve $domain:443:$ip $HTTPS_URL)

https_insecure=$(curl -o /dev/null -s -k -m 5 -w "%{http_code}" \
    --resolve $domain:443:$ip $HTTPS_URL)

echo -e "${YELLOW}HTTPS strict: $https_code${RESET}"
echo -e "${YELLOW}HTTPS insecure: $https_insecure${RESET}"

# ==================================================
# DECISION ENGINE
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
# RESULT
# ==================================================
echo ""
echo -e "${CYAN}=== RESULT ===${RESET}"
echo -e "URL: ${GREEN}$USE_URL${RESET}"
echo -e "Browser: ${GREEN}$BROWSER${RESET}"
echo -e "Reason: ${YELLOW}$REASON${RESET}"

# ==================================================
# OPEN (safe)
# ==================================================
read -p "Press Enter to open..."

if command -v "$BROWSER" >/dev/null 2>&1; then
    $BROWSER "$USE_URL"
else
    echo -e "${RED}[WARN] $BROWSER not found → using curl${RESET}"
    curl -I "$USE_URL" --resolve "$domain:443:$ip" -m 5
fi

# ==================================================
# CLEANUP END
# ==================================================
cleanup
echo -e "${GREEN}[+] Hosts entry removed${RESET}"
