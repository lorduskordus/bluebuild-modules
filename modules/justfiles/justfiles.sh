#!/usr/bin/env bash

set -euo pipefail

# Get all selected folders/files from user
get_yaml_array CONFIG_SELECTION '.include[]' "$1"

IMPORT_FILE="/usr/share/ublue-os/just/60-custom.just"
CONFIG_FOLDER="${CONFIG_DIRECTORY}/justfiles"
DEST_FOLDER="/usr/share/bluebuild/justfiles"

# Abort if justfiles folder is not present
if [ ! -d "${CONFIG_FOLDER}" ]; then
    echo "Error: The config folder '${CONFIG_FOLDER}' was not found."
    exit 1
fi

# Include all files in the folder if none specified
if [[ ${#CONFIG_SELECTION[@]} == 0 ]]; then
    CONFIG_SELECTION=($(ls "${CONFIG_FOLDER}"))
fi

# For every folder/file user specified, do
for selected in "${CONFIG_SELECTION[@]}"; do

    echo "---------- Adding folder/file '${selected}' ---------"

    # Find all justfiles, starting from 'selected' and get their paths
    JUSTFILES=($(find "${CONFIG_FOLDER}/${selected}" -type f -name "*.just" | sed "s|${CONFIG_FOLDER}/||g"))

    # Abort if no justfiles found at 'selected', else continue
    if [[ ${#JUSTFILES[@]} == 0 ]]; then
        echo "Error: No justfiles were found in '${CONFIG_FOLDER}/${selected}'."
        exit 1
    fi

    # Validate all found justfiles if set to do so
    if [ "$(echo "$1" | yq -I=0 ".validate")" == "true" ]; then

        echo "-- Validating justfiles"
        VALIDATION_FAILED=0
        for justfile in "${JUSTFILES[@]}"; do
            if ! /usr/bin/just --fmt --check --unstable --justfile "${CONFIG_FOLDER}/${justfile}" &> /dev/null; then
                echo "The justfile '${justfile}' FAILED validation."
                VALIDATION_FAILED=1
            fi
        done

        # Exit if any justfiles are not valid
        if [ ${VALIDATION_FAILED} -eq 1 ]; then
            echo "Error: Some justfiles didn't pass validation."
            exit 1
        else
            echo "All justfiles passed validation."
        fi

    fi

    # Copy 'selected' to destination folder
    echo "-- Copying folders/files"
    mkdir -p "${DEST_FOLDER}/$(dirname ${selected})"
    cp -rfT "${CONFIG_FOLDER}/${selected}" "${DEST_FOLDER}/${selected}"
    echo "Copied '${CONFIG_FOLDER}/${selected}' to '${DEST_FOLDER}/${selected}'."

    # Generate import lines for all found justfiles
    echo "-- Adding import lines"
    for justfile in "${JUSTFILES[@]}"; do

        # Create an import line
        IMPORT_LINE="import \"${DEST_FOLDER}/${justfile}\""
        
        # Abort if import line already exists, else append it to import file
        if grep -wq "${IMPORT_LINE}" "${IMPORT_FILE}"; then
            echo "Error: Duplicated import line: '${IMPORT_LINE}' found."
            exit 1
        else
            echo "${IMPORT_LINE}" | tee -a "${IMPORT_FILE}"
        fi

    done
    
    echo "------------------------------------------------"

done
