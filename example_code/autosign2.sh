
#!/bin/bash
# Autosign script that validates CSR challengePassword against Hiera
# Requires: puppet lookup, openssl

set -euo pipefail

CERTNAME="${1:-}"

if [ -z "$CERTNAME" ]; then
  echo "DEBUG: No certname provided to autosign script" >&2
  exit 1
fi

# --- Locate the CSR ---------------------------------------------------------

# Default CSR directory for Puppet Server 6+ / PE
CSR_DIR="/etc/puppetlabs/puppetserver/ca/requests"

CSR_PATH="${CSR_DIR}/${CERTNAME}.pem"

if [ ! -f "$CSR_PATH" ]; then
  echo "DEBUG: CSR for ${CERTNAME} not found in ${CSR_DIR}" >&2
  exit 1
fi

# --- Extract challengePassword from CSR -------------------------------------

challengePassword="$(
  openssl req -noout -text -in "$CSR_PATH" 2>/dev/null |
    awk -F: '/Challenge Password/ {
      # Trim leading whitespace in field 2
      gsub(/^[ \t]+/, "", $2);
      print $2;
      exit
    }'
)"

if [ -z "$challengePassword" ]; then
  echo "DEBUG: No challengePassword found in CSR for ${CERTNAME}" >&2
  exit 1
fi

# --- Determine environment for lookup --------------------------------------
# For a simple setup, we just use a fixed environment (default: production).
# You can override this by exporting AUTOSIGN_ENVIRONMENT on the Puppet Server.

## Don know if i need this ENVIRONMENT="${AUTOSIGN_ENVIRONMENT:-production}"

# --- Lookup expected password from Hiera ------------------------------------

# We use `|| true` so a failed lookup doesn't abort the script due to `set -e`
expectedPassword="$(
  puppet lookup autosign::password \
    --environment "$ENVIRONMENT" \
    --node "$CERTNAME" \
    --render-as s 2>/dev/null || true
)"

if [ -z "$expectedPassword" ]; then
  echo "DEBUG: Could not look up autosign::password from Hiera (env=${ENVIRONMENT})" >&2
  exit 1
fi

# --- Compare CSR password to Hiera password ---------------------------------

if [ "$challengePassword" = "$expectedPassword" ]; then
  echo "DEBUG: autosign accepted ${CERTNAME} (password matched Hiera)" >&2
  exit 0
else
  echo "DEBUG: autosign rejected ${CERTNAME} (password mismatch)" >&2
  exit 1
fi
