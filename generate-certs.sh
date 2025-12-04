#!/bin/bash
# Script to generate all required certificates for testing
# This creates certificates for both mTLS server and client functionality

set -e

CERTS_DIR="./certs"

echo "Creating certificates directory..."
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

echo ""
echo "=== Creating CA for client certificates (validates clients connecting to Apache) ==="
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=Test CA"

echo ""
echo "=== Creating Apache server certificate ==="
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=localhost"
printf "subjectAltName = DNS:localhost,IP:127.0.0.1\n" > ext.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256 -extfile ext.cnf

echo ""
echo "=== Creating client certificate (for testing client → Apache) ==="
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=test-client"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256

echo ""
echo "=== Creating upstream CA and certificates (for mTLS upstream service) ==="
openssl genrsa -out upstream-ca.key 4096
openssl req -x509 -new -nodes -key upstream-ca.key -sha256 -days 3650 -out upstream-ca.crt -subj "/CN=Upstream CA"

echo ""
echo "=== Creating upstream server certificate ==="
openssl genrsa -out upstream-server.key 2048
openssl req -new -key upstream-server.key -out upstream-server.csr -subj "/CN=mtls-upstream"
openssl x509 -req -in upstream-server.csr -CA upstream-ca.crt -CAkey upstream-ca.key -CAcreateserial -out upstream-server.crt -days 365 -sha256

echo ""
echo "=== Creating proxy client certificate (Apache uses this to authenticate to upstream) ==="
openssl genrsa -out proxy-client.key 2048
openssl req -new -key proxy-client.key -out proxy-client.csr -subj "/CN=apache-proxy-client"
openssl x509 -req -in proxy-client.csr -CA upstream-ca.crt -CAkey upstream-ca.key -CAcreateserial -out proxy-client.crt -days 365 -sha256

echo ""
echo "=== Creating proxy client bundle (certificate + key) ==="
cat proxy-client.crt proxy-client.key > proxy-client-bundle.pem

echo ""
echo "=== Cleaning up temporary files ==="
rm -f *.csr *.cnf *.srl

echo ""
echo "✓ All certificates created successfully in $CERTS_DIR/"
echo ""
echo "Certificate summary:"
echo "  Apache Server: server.crt, server.key"
echo "  Client CA: ca.crt"
echo "  Test Client: client.crt, client.key"
echo "  Upstream Server: upstream-server.crt, upstream-server.key"
echo "  Upstream CA: upstream-ca.crt"
echo "  Proxy Client Bundle: proxy-client-bundle.pem"
echo ""
echo "You can now run: docker compose up --build"
