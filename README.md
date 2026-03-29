# Staging Hosts Tester

A lightweight CLI tool for testing websites on a specific server IP without modifying DNS records.

---

##  Overview

This tool allows you to test a domain against a new server IP before DNS propagation by temporarily overriding routing and directly testing HTTP/HTTPS behavior.

Designed for staging, migration, and debugging environments.

---

##  Features (v2)

- Temporary `/etc/hosts` override
- Direct IP testing using `curl --resolve`
- Smart HTTP / HTTPS detection
- SSL / SNI issue detection
- Automatic fallback (HTTPS → HTTP)
- Terminal browser preview (`elinks` / `w3m`)
- Interactive browser selection
- Default selection with Enter key
- Retry logic for input validation
- Timeout handling
- Clean and structured output
- Automatic cleanup after execution

---

##  Requirements

- curl
- elinks
- w3m (optional)

Install on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install curl elinks w3m
