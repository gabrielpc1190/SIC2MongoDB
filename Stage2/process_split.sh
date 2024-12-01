#!/bin/bash

# Function to prompt user for input with a default value
prompt() {
    local message=$1
    local default=$2
    read -p "$message [$default]: " input
    echo "${input:-$default}"
}

# Default values for parameters
DEFAULT_INPUT_FILE="input_fisica.csv"
DEFAULT_OUTPUT_PREFIX="output_part_"
DEFAULT_LINES_PER_PART=1000000
DEFAULT_PARALLEL_PROCESSES=4

# Get parameters from user
INPUT_FILE=$(prompt "Enter the input CSV file" "$DEFAULT_INPUT_FILE")
OUTPUT_PREFIX=$(prompt "Enter the output prefix for split files" "$DEFAULT_OUTPUT_PREFIX")
LINES_PER_PART=$(prompt "Enter the number of lines per split part" "$DEFAULT_LINES_PER_PART")
PARALLEL_PROCESSES=$(prompt "Enter the number of parallel processes to run" "$DEFAULT_PARALLEL_PROCESSES")

# Check if the input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

# Split the input file into smaller parts
echo "Splitting input file into parts..."
split -l "$LINES_PER_PART" --additional-suffix=.csv "$INPUT_FILE" "$OUTPUT_PREFIX"

# Get the list of split files
SPLIT_FILES=($(ls ${OUTPUT_PREFIX}*.csv))

# Define the processing function
process_file() {
    local part_file=$1
    local output_file="${part_file%.csv}_processed.csv"
    local error_log="${part_file%.csv}_errors.log"
    local success_log="${part_file%.csv}_success.log"

    # Clear logs for a fresh start
    > "$error_log"
    > "$success_log"

    # Read the header line and write it to the output file
    if [[ ! -s "$output_file" ]]; then
        header=$(head -n 1 "$part_file")
        echo "$header,\"CEDULA_EXTRA\"" > "$output_file"
    fi

    # Determine the last processed line from the success log
    last_processed_line=$(tail -n 1 "$success_log" 2>/dev/null | awk '{print $NF}')
    last_processed_line=${last_processed_line:-0}

    # Process the file line by line, skipping processed lines
    line_number=1
    tail -n +2 "$part_file" | while IFS=',' read -r line; do
        ((line_number++))

        # Skip lines that have already been processed
        if (( line_number <= last_processed_line )); then
            continue
        fi

        # Extract the CEDULA field (assumes it's the first field)
        cedula=$(echo "$line" | cut -d',' -f1 | tr -d '"')
        if [[ -z "$cedula" ]]; then
            echo "Warning: Empty CEDULA on line $line_number. Skipping line." >> "$error_log"
            continue
        fi

        # Split into CEDULA (10 digits) and CEDULA_EXTRA
        cedula_10="${cedula:0:10}"
        cedula_extra="${cedula:10}"

        # Replace the original CEDULA with the 10-digit one
        modified_line=$(echo "$line" | sed "s/^\"$cedula\"/\"$cedula_10\"/")

        # Add the new CEDULA_EXTRA field
        echo "$modified_line,\"$cedula_extra\"" >> "$output_file"

        # Log success with the line number
        echo "Line $line_number processed successfully." >> "$success_log"
    done
}

export -f process_file

# Run processing in parallel
echo "Processing split files in parallel..."
parallel -j "$PARALLEL_PROCESSES" process_file ::: "${SPLIT_FILES[@]}"

# Merge results into a single output file
MERGED_OUTPUT="final_output.csv"
echo "Merging processed files into $MERGED_OUTPUT..."
head -n 1 "${SPLIT_FILES[0]}" > "$MERGED_OUTPUT"
tail -n +2 -q ${OUTPUT_PREFIX}*_processed.csv >> "$MERGED_OUTPUT"

echo "Processing completed. Final output saved to $MERGED_OUTPUT."