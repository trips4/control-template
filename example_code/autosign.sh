  #autosign.sh goes in /etc/puppetlabs/puppetserver/autosign.sh
  #chmod 755 /etc/puppetlabs/puppetserver/autosign.sh
  #chown pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/aut
  #service pe-puppetserver reload
  #contents of /etc/puppetlabs/puppet on agent csr_attributes.yaml
  #custom_attributes:
  #  challengePassword: 'b6137757c1f886d4027fa8b97287967cb0ef6cdb504626b1d20f3179d4e31311'
  #to view contents of csr openssl req -in lab1-ubuagt01.triplo.psedemos.com.pem -noout -text
  #when using linux install script -s custom_attributes:challentgePassword=<password>


#!/bin/bash
# Shared "secret" that must match the CSR's challengePassword
PASSWORD="b6137757c1f886d4027fa8b97287967cb0ef6cdb504626b1d20f3179d4e31311"

CERT_NAME="$1"

# Ensure we got a certname
if [[ -z "$CERT_NAME" ]]; then
  echo "No certname provided to autosign script" >&2
  exit 1
fi

CSR_PATH="/etc/puppetlabs/puppetserver/ca/requests/${CERT_NAME}.pem"

# Ensure the CSR file exists
if [[ ! -f "$CSR_PATH" ]]; then
  echo "CSR not found for certname: $CERT_NAME ($CSR_PATH)" >&2
  exit 1
fi

# Extract the challengePassword from the CSR
AGENT_PASSWORD=$(
  openssl req -noout -text -in "$CSR_PATH" 2>/dev/null \
    | awk -F: '/challengePassword/ {gsub(/^[ \t]+/, "", $2); print $2}'
)

# If we couldn't parse a password, fail closed
if [[ -z "$AGENT_PASSWORD" ]]; then
  echo "No challengePassword found in CSR for $CERT_NAME" >&2
  exit 1
fi

# Debug logging (optional - but be careful exposing secrets)
echo "DEBUG: cert=$CERT_NAME challengePassword=$AGENT_PASSWORD" >&2

# Compare with the expected password
if [[ "$AGENT_PASSWORD" == "$PASSWORD" ]]; then
  # Exit 0 means "autosign allowed"
  exit 0
else
  # Non-zero means "do not autosign"
  exit 1
fi