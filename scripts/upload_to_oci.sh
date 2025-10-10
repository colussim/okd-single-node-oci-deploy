#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
SCRIPT_DIR="${ROOT_DIR}/scripts"

# Utils + .env load (must export REGION, BUCKET, CLUSTER_NAME, PRESIGN_DAYS, etc.)
source "${SCRIPT_DIR}/utils.sh"

# ---------- Fonctions ----------
expires_in_days() {
  local days="${1:-365}"
  if date -u -v+1d '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
    date -u -v+"${days}"d '+%Y-%m-%dT%H:%M:%SZ'
  elif date -u -d "+${days} days" '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
    date -u -d "+${days} days" '+%Y-%m-%dT%H:%M:%SZ'
  else
    echo "ERROR: 'date' does not support ni -v ni -d" >&2
    return 1
  fi
}

# ---------- Required variables ----------
: "${REGION:?REGION manquant}"
: "${BUCKET:?BUCKET manquant}"
: "${CLUSTER_NAME:?CLUSTER_NAME manquant}"
: "${PRESIGN_DAYS:=365}"

# Path to the pre-installed image (created in step 1)
# Default: images/scos-okd-sno.qcow2 (can be overridden via .env: SCOS_IMAGE_FILE)
RAW_FILE_DEFAULT="images/scos-metal.vmdk"
RAW_FILE="${SCOS_IMAGE_FILE:-$RAW_FILE_DEFAULT}"
test -s "${RAW_FILE}" || { echo "RAW image not found: ${RAW_FILE}"; exit 1; }

# Checksum
if [ -f "${RAW_FILE}.sha256" ]; then
  SHA_FILE="${RAW_FILE}.sha256"
else
  echo ">> Generates SHA256 (${RAW_FILE}.sha256)"
  sha256sum "${RAW_FILE}" > "${RAW_FILE}.sha256"
  SHA_FILE="${RAW_FILE}.sha256"
fi

# Names of objects in the bucket
OBJECT_PREFIX="images/scos/${CLUSTER_NAME}"
OBJ_IMG="${OBJECT_PREFIX}/scos-metal.vmdk"
OBJ_IMG_SHA="${OBJ_IMG}.sha256"

echo ">> Namespace Object Storage"
NS="$(oci os ns get --query 'data' --raw-output)"

# ---------- Upload image (multipart) ----------
echo ">> Upload SCOS image: ${OBJ_IMG} (multipart; long)"
oci os object put \
  --bucket-name "${BUCKET}" \
  --name "${OBJ_IMG}" \
  --file "${RAW_FILE}" \
  --part-size 1024 \
  --parallel-upload-count 8 \
  --content-type "application/octet-stream" \
  >/dev/null

# ---------- Upload checksum ----------
echo ">> Upload checksum: ${OBJ_IMG_SHA}"
oci os object put \
  --bucket-name "${BUCKET}" \
  --name "${OBJ_IMG_SHA}" \
  --file "${SHA_FILE}" \
  --content-type "text/plain" \
  >/dev/null

# ---------- PAR (pre-auth request) pour l'image ----------
EXP="$(expires_in_days "${PRESIGN_DAYS}")"

echo ">> PAR creation for the image"
IMG_AR="$(oci os preauth-request create \
  --bucket-name "${BUCKET}" \
  --name "img-${CLUSTER_NAME}" \
  --access-type ObjectRead \
  --object-name "${OBJ_IMG}" \
  --time-expires "${EXP}" \
  --query 'data."access-uri"' --raw-output)"
SCOS_IMAGE_URL="https://objectstorage.${REGION}.oraclecloud.com${IMG_AR}"

# ---------- JSON output for the next step ----------
WORKDIR="workdir/${CLUSTER_NAME}"
mkdir -p "${WORKDIR}"
OUT_JSON="${WORKDIR}/stage2-uploads.json"

jq -n \
  --arg img "$SCOS_IMAGE_URL" \
  --arg ns "$NS" \
  --arg bucket "$BUCKET" \
  --arg obj_img "$OBJ_IMG" \
  '{
    SCOS_IMAGE_URL: $img,
    NAMESPACE: $ns,
    BUCKET: $bucket,
    OBJECTS: { image: $obj_img }
  }' | tee "${OUT_JSON}"

echo
echo "SCOS_IMAGE_URL=${SCOS_IMAGE_URL}"
echo "→ Output file: ${OUT_JSON}"
