#!/usr/bin/env bash
# sigaa_login.sh - Authenticate to SIGAA via CAS SSO
# Usage: source sigaa_login.sh <base_url> <username> <password> [cookie_file]
# After sourcing: $SIGAA_COOKIE_FILE and $SIGAA_USER_ID are set
# Returns: 0 on success, 1 on failure
#
# Supported login modes:
#   - CAS SSO (autenticacao.unb.br style) - UNB and most institutions
#   - Direct login (sigaa.*/sigaa/logar.do) - older deployments
#
# Example:
#   source sigaa_login.sh "https://sigaa.unb.br" "241104251" "mypassword"
#   source sigaa_login.sh "https://sigaa.ufpe.br" "myuser" "mypassword"

set -euo pipefail

SIGAA_BASE_URL="${1:-}"
SIGAA_USERNAME="${2:-}"
SIGAA_PASSWORD="${3:-}"
SIGAA_COOKIE_FILE="${4:-/tmp/sigaa_session_$$.txt}"

if [[ -z "$SIGAA_BASE_URL" || -z "$SIGAA_USERNAME" || -z "$SIGAA_PASSWORD" ]]; then
  echo "Usage: source sigaa_login.sh <base_url> <username> <password> [cookie_file]" >&2
  return 1 2>/dev/null || exit 1
fi

AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
rm -f "$SIGAA_COOKIE_FILE"

# Step 1: Hit the SIGAA login endpoint - follows redirect to CAS or shows direct login
INITIAL_URL=$(curl -s -o /dev/null -w "%{url_effective}" -L \
  -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
  -A "$AGENT" \
  "${SIGAA_BASE_URL}/sigaa/verTelaLogin.do" 2>/dev/null || \
  curl -s -o /dev/null -w "%{url_effective}" -L \
  -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
  -A "$AGENT" \
  "${SIGAA_BASE_URL}/sigaa/logar.do" 2>/dev/null)

# Detect if redirected to CAS SSO
if echo "$INITIAL_URL" | grep -qi "autenticacao\|sso\|cas\|login"; then
  # CAS SSO flow
  LOGIN_PAGE=$(curl -s -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
    -A "$AGENT" "$INITIAL_URL")

  ACTION_PATH=$(echo "$LOGIN_PAGE" | grep -oP 'action="[^"]*"' | head -1 | sed 's/action="//;s/"//')
  LT=$(echo "$LOGIN_PAGE" | grep 'name="lt"' | grep -oP 'value="[^"]*"' | sed 's/value="//;s/"//')
  EXEC=$(echo "$LOGIN_PAGE" | grep 'name="execution"' | grep -oP 'value="[^"]*"' | sed 's/value="//;s/"//')

  # Extract CAS base from URL
  CAS_BASE=$(echo "$INITIAL_URL" | grep -oP 'https?://[^/]+')
  FULL_ACTION="${CAS_BASE}${ACTION_PATH}"

  RESULT=$(curl -s -L \
    -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
    -A "$AGENT" \
    -X POST "$FULL_ACTION" \
    --data-urlencode "username=${SIGAA_USERNAME}" \
    --data-urlencode "password=${SIGAA_PASSWORD}" \
    --data-urlencode "lt=${LT}" \
    --data-urlencode "execution=${EXEC}" \
    -d "_eventId=submit" \
    -w "\n__HTTP_CODE__:%{http_code}__FINAL_URL__:%{url_effective}")

  HTTP_CODE=$(echo "$RESULT" | grep -oP '__HTTP_CODE__:\K[0-9]+')
  FINAL_URL=$(echo "$RESULT" | grep -oP '__FINAL_URL__:\K.*')

  # Check for failed login (stayed on CAS page)
  if echo "$RESULT" | grep -qi "credenciais inv\|invalid credential\|incorrect password\|login-error"; then
    echo "ERROR: Invalid credentials for user '${SIGAA_USERNAME}'" >&2
    return 1 2>/dev/null || exit 1
  fi
else
  # Direct login flow (older SIGAA instances)
  LOGIN_PAGE=$(curl -s -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
    -A "$AGENT" "${SIGAA_BASE_URL}/sigaa/verTelaLogin.do")

  VIEWSTATE=$(echo "$LOGIN_PAGE" | grep -oP 'name="javax.faces.ViewState"[^>]*value="\K[^"]+')

  RESULT=$(curl -s -L \
    -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
    -A "$AGENT" \
    -X POST "${SIGAA_BASE_URL}/sigaa/logar.do" \
    -d "dispatch=logOn" \
    --data-urlencode "user.login=${SIGAA_USERNAME}" \
    --data-urlencode "user.senha=${SIGAA_PASSWORD}" \
    --data-urlencode "javax.faces.ViewState=${VIEWSTATE}" \
    -w "\n__HTTP_CODE__:%{http_code}__FINAL_URL__:%{url_effective}")

  HTTP_CODE=$(echo "$RESULT" | grep -oP '__HTTP_CODE__:\K[0-9]+')
  FINAL_URL=$(echo "$RESULT" | grep -oP '__FINAL_URL__:\K.*')

  if echo "$RESULT" | grep -qi "senha ou login inv\|Usu.rio e/ou Senha"; then
    echo "ERROR: Invalid credentials for user '${SIGAA_USERNAME}'" >&2
    return 1 2>/dev/null || exit 1
  fi
fi

# Extract user ID from portal page (needed for menu navigation)
PORTAL_HTML=$(curl -s -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
  -A "$AGENT" \
  "${SIGAA_BASE_URL}/sigaa/verPortalDiscente.do" 2>/dev/null || \
  curl -s -c "$SIGAA_COOKIE_FILE" -b "$SIGAA_COOKIE_FILE" \
  -A "$AGENT" \
  "${SIGAA_BASE_URL}/sigaa/portais/discente/discente.jsf")

SIGAA_USER_ID=$(echo "$PORTAL_HTML" | grep -oP 'name="id"\s+value="\K[0-9]+' | head -1)
export SIGAA_COOKIE_FILE
export SIGAA_USER_ID
export SIGAA_BASE_URL

if [[ -n "$SIGAA_USER_ID" ]]; then
  echo "OK: Logged in as user ID $SIGAA_USER_ID (cookie: $SIGAA_COOKIE_FILE)"
else
  echo "WARNING: Logged in but could not extract user ID (may still work)"
fi
