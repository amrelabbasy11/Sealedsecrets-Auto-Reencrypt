#!/bin/bash

set -e

CERT_FILE="cert.pem"

echo "[INFO] Fetching Sealed Secrets public key..."
kubeseal --fetch-cert > "$CERT_FILE"

mkdir -p sealedsecrets-reencrypted

echo "[INFO] Re-encrypting sealed secrets..."
for file in sealedsecrets/*.yaml; do
  fname=$(basename "$file")
  echo "[INFO] Processing $fname"
  kubeseal --re-encrypt --cert "$CERT_FILE" < "$file" > sealedsecrets-reencrypted/"$fname"
  mv sealedsecrets-reencrypted/"$fname" sealedsecrets/"$fname"
done

echo "[SUCCESS] Re-encryption completed"
