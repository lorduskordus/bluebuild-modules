#!/usr/bin/env bash

set -euo pipefail

get_json_array CONFIG_SELECTION 'try .["include"][]' "$1"
VALIDATE="$(echo "$1" | jq -r 'try .["validate"]')"
USING_UJUST="$(echo "$1" | jq -r 'try .["using-ujust"]')"

MODULE_DIRECTORY="${MODULE_DIRECTORY:-"/tmp/modules"}"
CONFIG_FOLDER="${CONFIG_DIRECTORY}/justfiles"
DEST_FOLDER="/usr/share/bluebuild/justfiles"

# Abort if justfiles folder is not present
if [ ! -d "${CONFIG_FOLDER}" ]; then
    echo "Error: The config folder '${CONFIG_FOLDER}' was not found."
    exit 1
fi

# Install just if not present
echo "Checking if package 'just' is installed"
if ! rpm -q just &> /dev/null; then
    echo "- Package is not installed, installing..."
    dnf5 install -y just
else
    echo "- Package is installed."
fi

# Import to '60-custom.just' by default (uBlue) else to 'justfile' in the bluebuild folder
if [ "${USING_UJUST}" == "false" ]; then
    IMPORT_FILE="${DEST_FOLDER}/justfile"

    mkdir -p "${DEST_FOLDER}"
    
    if [ ! -f "${IMPORT_FILE}" ]; then
        cp "${MODULE_DIRECTORY}/justfiles/justfile" "${IMPORT_FILE}"
    fi

    if [ ! -f "/usr/bin/bjust" ]; then
        install -o root -g root -m 755 "${MODULE_DIRECTORY}/justfiles/bjust" /usr/bin/bjust
    fi
else
    IMPORT_FILE="/usr/share/ublue-os/just/60-custom.just"
    
    if [ ! -f "${IMPORT_FILE}" ]; then
        touch "${IMPORT_FILE}"
    fi
fi
echo "Import lines will be written in: '${IMPORT_FILE}'"

# Include all files in the folder if none specified
if [[ ${#CONFIG_SELECTION[@]} == 0 ]]; then
    CONFIG_SELECTION=($(find "${CONFIG_FOLDER}" -mindepth 1 -maxdepth 1 -exec basename {} \;))
fi

for SELECTED in "${CONFIG_SELECTION[@]}"; do

    echo "------------------------------------------------------------------------"
    echo "--- Adding folder/file '${SELECTED}'"
    echo "------------------------------------------------------------------------"

    # Find all justfiles, starting from 'SELECTED' and get their paths
    JUSTFILES=($(find "${CONFIG_FOLDER}/${SELECTED}" -type f -name "*.just" | sed "s|${CONFIG_FOLDER}/||g"))

    # Abort if no justfiles found at 'SELECTED'
    if [[ ${#JUSTFILES[@]} == 0 ]]; then
        echo "Error: No justfiles were found in '${CONFIG_FOLDER}/${SELECTED}'."
        exit 1
    fi

    # Validate all found justfiles if set to do so
    if [ "${VALIDATE}" == "true" ]; then

        echo "Validating justfiles"
        VALIDATION_FAILED=0
        for JUSTFILE in "${JUSTFILES[@]}"; do
            if ! /usr/bin/just --fmt --check --unstable --justfile "${CONFIG_FOLDER}/${JUSTFILE}" &> /dev/null; then
                echo "- The justfile '${JUSTFILE}' FAILED validation."
                VALIDATION_FAILED=1
            fi
        done

        # Exit if any justfiles are not valid
        if [ ${VALIDATION_FAILED} -eq 1 ]; then
            echo "Error: Some justfiles didn't pass validation."
            exit 1
        else
            echo "- All justfiles passed validation."
        fi

    fi

    # Copy 'SELECTED' to destination folder
    echo "Copying folders/files"
    mkdir -p "${DEST_FOLDER}/$(dirname ${SELECTED})"
    cp -rfT "${CONFIG_FOLDER}/${SELECTED}" "${DEST_FOLDER}/${SELECTED}"
    echo "- Copied '${CONFIG_FOLDER}/${SELECTED}' to '${DEST_FOLDER}/${SELECTED}'."

    # Generate import lines for all found justfiles
    echo "Adding import lines"
    for JUSTFILE in "${JUSTFILES[@]}"; do

        # Create an import line
        IMPORT_LINE="import \"${DEST_FOLDER}/${JUSTFILE}\""
        
        # Skip the import line if it already exists, else append it to import file
        if grep -wq "${IMPORT_LINE}" "${IMPORT_FILE}"; then
            echo "- Skipped: '${IMPORT_LINE}' (already present)"
        else
            echo "${IMPORT_LINE}" >> "${IMPORT_FILE}"
            echo "- Added: '${IMPORT_LINE}'"
        fi

    done

done
