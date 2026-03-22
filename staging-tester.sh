#!/bin/bash


# Colors

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


# Check root

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR] Run as root (sudo)${NC}"
   exit 1
fi


# Cleanup on exit

cleanup() {
    if [[ -n "$HOST_ENTRY" ]]; then
        sed -i "\|$DOMAIN|d" /etc/hosts
        echo -e "${GREEN}[+] /etc/hosts cleaned${NC}"
    fi
}
trap cleanup EXIT


# Input validation

read -p "IP: " IP
if ! [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "${RED}Invalid IP format${NC}"
    exit 1
fi

read -p "Domain: " DOMAIN
if ! [[ $DOMAIN =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}Invalid domain format${NC}"
    exit 1
fi


# Update hosts

echo "$IP $DOMAIN" >> /etc/hosts
HOST_ENTRY="$IP $DOMAIN"
echo -e "${GREEN}[+] Hosts updated${NC}"


# Curl tests

echo -e "${BLUE}[+] Testing HTTP...${NC}"
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" http://$DOMAIN)

echo -e "${YELLOW}HTTP code: $HTTP_CODE${NC}"

echo -e "${BLUE}[+] Testing HTTPS...${NC}"
HTTPS_CODE=$(curl -o /dev/null -s -w "%{http_code}" https://$DOMAIN --max-time 10)

echo -e "${YELLOW}HTTPS code: $HTTPS_CODE${NC}"


# SSL/SNI detection

USE_SSL=0
FINAL_URL="http://$DOMAIN"

if [[ "$HTTPS_CODE" != "000" && "$HTTPS_CODE" != "" ]]; then
    USE_SSL=1
    FINAL_URL="https://$DOMAIN"
fi

echo -e "${GREEN}[+] Selected URL: $FINAL_URL${NC}"


# Browser selection

echo ""
echo "[1] elinks"
echo "[2] w3m fallback"
read -p "Choose browser (default 1): " CHOICE


# Open site

if [[ "$CHOICE" == "2" ]]; then
    w3m "$FINAL_URL"
else
    elinks "$FINAL_URL"
fi