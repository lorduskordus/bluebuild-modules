#!/usr/bin/env bash

set -euo pipefail

# Get config
get_yaml_array REPLACEMENTS '.replace[]' "$1"

# Abort if no config provided
if [[ ${#REPLACEMENTS[@]} == 0 ]]; then
    echo "No replacements provided."
    exit 1
fi

for replacement in "${REPLACEMENTS[@]}"; do

    # Get Repository
    REPO=$(echo "${replacement}" | yq -I=0 ".from-repo")
    # Replace '%OS_VERSION%' with the current Fedora version
    REPO=${REPO//%OS_VERSION%/${OS_VERSION}}

    # Get packages to replace
    get_yaml_array PACKAGES '.packages[]' "${replacement}"
    PACKAGES=$(echo "${PACKAGES[*]}" | tr -d '\n')

    # Ensure repository is provided
    if [[ "${REPO}" == "null" ]]; then
        echo "Error: Repository was not provided."
        exit 1
    fi

    # Ensure packages are provided
    if [ -z "${PACKAGES}" ]; then
        echo "Error: No packages were provided."
        exit 1
    fi

    MAINTAINER=$(awk -F'/' '{print $5}' <<< "${REPO}")
    REPO_NAME=$(awk -F'/' '{print $6}' <<< "${REPO}")
    FILE_NAME=$(awk -F'/' '{print $9}' <<< "${REPO}")

    echo "-----------------------------------------------------------------------------------------------------"
    echo "------------ Replacing packages from repository: '${REPO_NAME}' owned by '${MAINTAINER}' ------------"
    echo "-----------------------------------------------------------------------------------------------------"

    wget -P "/etc/yum.repos.d/" "${REPO}"
    rpm-ostree override replace --experimental --from repo=copr:copr.fedorainfracloud.org:${MAINTAINER}:${REPO_NAME} ${PACKAGES}
    rm "/etc/yum.repos.d/${FILE_NAME}"

done