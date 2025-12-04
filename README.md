# Apache mTLS proxy to JSON (docker-compose)

## Overview
This project demonstrates Apache acting as **both** an mTLS server and an mTLS client:
- **mTLS Server**: Apache listens on port 443 and requires client certificate verification (mTLS). Clients must present valid certificates to access the service.
- **mTLS Client**: Apache acts as a client when proxying to an mTLS-secured upstream service, presenting its own client certificate for authentication.
- If the client TLS handshake succeeds, Apache can proxy to:
  - `/secure-json` → a simple backend static server (non-mTLS)
  - `/mtls-upstream` → an mTLS-secured upstream service (requires client certificates)
- You provide certificates by mounting a host directory into the container (default: `./certs`).

## Architecture
```
Client (with client cert) 
    ↓ mTLS
Apache (mTLS Server) 
    ↓ HTTP (no mTLS)
    → json-backend (returns JSON)
    
    ↓ HTTPS with mTLS (Apache as client)
    → mtls-upstream (mTLS-secured service)
```

## What you get
- **docker-compose.yml** — starts three services:
  - `apache` — the main mTLS proxy (acts as both server and client)
  - `json-backend` — simple nginx backend (non-mTLS)
  - `mtls-upstream` — mTLS-secured Apache upstream service
- **apache/** — Dockerfile and Apache site configuration that enables mod_ssl and mod_proxy with mTLS client support
- **mtls-upstream/** — Dockerfile and configuration for the mTLS-secured upstream service
- **backend/myfile.json** — the JSON file served by the simple backend

## Required files (place in `./certs` on the host)

### For Apache mTLS Server functionality:
- **server.crt** — Apache server certificate (PEM)
- **server.key** — Apache server private key (PEM)
- **ca.crt** — CA certificate that signs client certificates (PEM)

### For Apache mTLS Client functionality (NEW):
- **proxy-client-bundle.pem** — Combined client certificate and key for Apache to use when connecting to mTLS upstreams
  - Format: concatenated PEM file containing both certificate and private key
- **upstream-ca.crt** — CA certificate to verify the mTLS upstream server
- **upstream-server.crt** — mTLS upstream server certificate (PEM)
- **upstream-server.key** — mTLS upstream server private key (PEM)

### Optional for testing:
- **client.crt**, **client.key** — a client certificate and key signed by `ca.crt` (for testing client → Apache)

## How to run
1. Generate test certificates using the provided script:
   ```bash
   ./generate-certs.sh
   ```
   Or manually place your certificates in `./certs` (see "Certificate generation guide" below).
   - Files must be readable by Docker (they'll be mounted read-only).
2. Start the services:
   ```bash
   docker compose up --build
   ```
3. Test the mTLS server functionality (client → Apache):
   ```bash
   # Test the existing endpoint (proxies to json-backend)
   curl -v --cert ./certs/client.crt --key ./certs/client.key --cacert ./certs/ca.crt https://localhost:9443/secure-json
   
   # Test the NEW mTLS client endpoint (Apache → mtls-upstream)
   curl -v --cert ./certs/client.crt --key ./certs/client.key --cacert ./certs/ca.crt https://localhost:9443/mtls-upstream
   ```

If the client certificate is valid (signed by ca.crt and matches the key), you should get:
- `/secure-json` — JSON from the simple backend
- `/mtls-upstream` — JSON from the mTLS-secured upstream (Apache authenticated itself using proxy-client-bundle.pem)

If the client cert is invalid, the TLS handshake will be rejected.

## Certificate generation guide

This section provides OpenSSL commands to create test certificates for local testing only.

### 1) Create a CA for client certificates (validates clients connecting to Apache)
```bash
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=Test CA"
```

### 2) Create Apache server certificate
```bash
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=localhost"
# Create a small extfile to mark subjectAltName
printf "subjectAltName = DNS:localhost,IP:127.0.0.1\n" > ext.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256 -extfile ext.cnf
```

### 3) Create client certificate (for testing client → Apache)
```bash
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=test-client"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256
```

### 4) NEW: Create upstream CA and certificates (for mTLS upstream service)
```bash
# CA for the upstream service
openssl genrsa -out upstream-ca.key 4096
openssl req -x509 -new -nodes -key upstream-ca.key -sha256 -days 3650 -out upstream-ca.crt -subj "/CN=Upstream CA"

# Upstream server certificate
openssl genrsa -out upstream-server.key 2048
openssl req -new -key upstream-server.key -out upstream-server.csr -subj "/CN=mtls-upstream"
openssl x509 -req -in upstream-server.csr -CA upstream-ca.crt -CAkey upstream-ca.key -CAcreateserial -out upstream-server.crt -days 365 -sha256

# Proxy client certificate (Apache uses this to authenticate to upstream)
openssl genrsa -out proxy-client.key 2048
openssl req -new -key proxy-client.key -out proxy-client.csr -subj "/CN=apache-proxy-client"
openssl x509 -req -in proxy-client.csr -CA upstream-ca.crt -CAkey upstream-ca.key -CAcreateserial -out proxy-client.crt -days 365 -sha256

# Create the bundle (certificate + key) for Apache to use as mTLS client
cat proxy-client.crt proxy-client.key > proxy-client-bundle.pem
```

### Place all certificates in the `./certs` directory:
```bash
# Required files:
# - server.crt, server.key, ca.crt (Apache server)
# - client.crt, client.key (for testing)
# - upstream-ca.crt, upstream-server.crt, upstream-server.key (upstream service)
# - proxy-client-bundle.pem (Apache mTLS client)
```

Then run `docker compose up --build` and test with curl.

## Notes
- **Apache mTLS Server**: The proxy path `/secure-json` in Apache is proxied to `http://json-backend:80/myfile.json` (the backend service name in docker-compose). This does NOT use mTLS.
- **Apache mTLS Client (NEW)**: The proxy path `/mtls-upstream` connects to `https://mtls-upstream:443/protected.json` using client certificates from `proxy-client-bundle.pem`. The upstream validates Apache's client certificate.
- The Apache config sets `SSLVerifyClient require` for incoming connections and uses `SSLCACertificateFile /usr/local/apache2/certs/ca.crt` to validate client certificates.
- For outgoing connections to mTLS upstreams, Apache uses:
  - `SSLProxyMachineCertificateFile` to provide client credentials
  - `SSLProxyVerify require` to verify the upstream server
  - `SSLProxyCACertificateFile` to validate the upstream's certificate
- You may adjust `SSLVerifyDepth` if you have deeper certificate chains.
- For debugging TLS issues, check Apache logs in the container: `docker compose logs apache`
