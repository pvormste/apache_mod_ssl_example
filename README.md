# Apache mTLS proxy to JSON (docker-compose)

Overview
- Apache (custom image) listens on 443 and requires client certificate verification (mTLS).
- If the client TLS handshake succeeds, Apache proxies the path /secure-json to a backend static server that serves a JSON file.
- You provide certificates by mounting a host directory into the container (default: `./certs`).

What you get
- docker-compose.yml — starts `apache` and `json-backend` services.
- apache/ — Dockerfile and Apache site configuration that enables mod_ssl and mod_proxy.
- backend/myfile.json — the JSON file served by the backend.

Required files (place in `./certs` on the host)
- server.crt    — server certificate (PEM)
- server.key    — server private key (PEM)
- ca.crt        — CA certificate that signs client certificates (PEM)

(Optional for testing)
- client.crt, client.key — a client certificate and key signed by `ca.crt`

How to run
1. Place your certificates in `./certs` relative to the compose file (server.crt, server.key, ca.crt).
   - Files must be readable by Docker (they'll be mounted read-only).
2. Start:
   docker compose up --build
3. Test (from the machine where the client cert/key are available):
   curl -v --cert ./certs/client.crt --key ./certs/client.key --cacert ./certs/ca.crt https://localhost/secure-json

If the client certificate is valid (signed by ca.crt and matches the key), you should get the JSON contents. If not, the TLS handshake will be rejected.

OpenSSL commands to create a quick test CA, server and client (for local testing only)
1) CA:
   openssl genrsa -out ca.key 4096
   openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=Test CA"

2) Server:
   openssl genrsa -out server.key 2048
   openssl req -new -key server.key -out server.csr -subj "/CN=localhost"
   # Create a small extfile to mark subjectAltName
   printf "subjectAltName = DNS:localhost,IP:127.0.0.1\n" > ext.cnf
   openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256 -extfile ext.cnf

3) Client:
   openssl genrsa -out client.key 2048
   openssl req -new -key client.key -out client.csr -subj "/CN=test-client"
   openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256

Put server.crt, server.key, ca.crt, client.crt, client.key into `./certs` and then run docker compose up --build and test with curl.

Notes
- The proxy path in Apache is /secure-json and is proxied to http://json-backend:8080/myfile.json (the backend service name in docker-compose).
- The Apache config sets `SSLVerifyClient require` and uses `SSLCACertificateFile /etc/apache2/certs/ca.crt`. You may adjust `SSLVerifyDepth` if you have deeper chains.
- For debugging TLS issues, check Apache logs in the container: docker compose logs apache
