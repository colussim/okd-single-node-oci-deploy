#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(echo $PWD)"
SCRIPT_DIR="${ROOT_DIR}/scripts"

source "${SCRIPT_DIR}/utils.sh"

: "${CLUSTER_NAME:?CLUSTER_NAME manquant}"
: "${BASE_DOMAIN:?BASE_DOMAIN manquant}"
: "${ARCH:=amd64}"
: "${CIDR:?CIDR manquant}"
: "${CLUSTER_NETWORK_CIDR:=10.128.0.0/14}"
: "${CLUSTER_NETWORK_HOSTPREFIX:=23}"
: "${SERVICE_NETWORK_CIDR:=172.30.0.0/16}"
: "${PULL_SECRET:?PULL_SECRET manquant}"
: "${SSH_PUBKEY:?SSH_PUBKEY manquant}"

WORKDIR="workdir/${CLUSTER_NAME}"
mkdir -p "${WORKDIR}"

export CLUSTER_NAME BASE_DOMAIN ARCH CIDR \
  CLUSTER_NETWORK_CIDR CLUSTER_NETWORK_HOSTPREFIX SERVICE_NETWORK_CIDR \
  PULL_SECRET SSH_PUBKEY

envsubst < terraform/templates/install-config.yaml.tmpl > "${WORKDIR}/install-config.yaml"

echo ">> Ignition Generation (without agent) in  ${WORKDIR} ..."
openshift-install create single-node-ignition-config --dir "${WORKDIR}" --log-level=debug
