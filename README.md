# Staging Hosts Tester

A lightweight CLI tool for testing websites on a new server IP without changing DNS.

## ? Features

* Temporary `/etc/hosts` override
* Smart HTTP/HTTPS detection
* SSL/SNI issue detection
* Automatic fallback (HTTP / w3m)
* Terminal browser preview (elinks / w3m)
* Auto cleanup after exit

## ?? Requirements

* curl
* elinks
* (optional) w3m

## ?? Usage

```bash
sudo bash staging-tester.sh
```

## ?? How it works

1. Injects temporary hosts entry
2. Tests HTTP/HTTPS using curl (--resolve)
3. Detects SSL issues
4. Opens best version in terminal browser
5. Cleans up automatically

## ?? Notes

* Requires root privileges
* Does not persist hosts changes
* Designed for staging/debug environments

## ?? License

MIT
