#!/bin/bash

echo "[+] Installing dependencies..."

if command -v apt >/dev/null; then
    apt update
    apt install -y curl elinks w3m
elif command -v yum >/dev/null; then
    yum install -y curl elinks w3m
elif command -v dnf >/dev/null; then
    dnf install -y curl elinks w3m
else
    echo "Unsupported OS"
    exit 1
fi

echo "[+] Making executable..."
chmod +x staging-tester.sh

echo "[+] Installed successfully"
echo "Run: sudo ./staging-tester.sh"