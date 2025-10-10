#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash
set -euo pipefail

# --- Loqd .env  ---
if [[ -f ".env" ]]; then
  set -a
  source ./.env
  set +a
fi

# Déps
need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }

need openshift-install || true
need oci || true
need jq || true
need envsubst || true
need curl || true
need xz || true

# SD date (macOS): +N days → ISO8601 UTC
expires_in_days() {
  local days="${1:-30}"
  date -u -v+"${days}"d +%Y-%m-%dT%H:%M:%SZ
}
