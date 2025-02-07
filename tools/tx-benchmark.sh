#!/bin/bash

usage() {
    echo "Usage: $0 -d <mount_directory> [--directory] [-f <sizes>] [--file-sizes] [-s] [--single] [-m] [--multiple] [-v] [--verbose]"
    echo "Options:"
    echo "  -d, --directory <dir>    Mount directory to test"
    echo "  -f, --file-sizes <sizes> Comma-separated list of sizes (e.g., '100M,500M,1G')"
    echo "  -s, --single            Run single file tests (default: false)"
    echo "  -m, --multiple          Run multiple small files tests (default: false)"
    echo "  -v, --verbose           Verbose output (default: false)"
    echo "  -h, --help              Show this help message"
    echo "  -l, --local             Skip mount point check for local/USB drives (default: false)"
    echo "  -q, --quiet             Quiet output, show results only (default: false)"

    # Exit with 0 if help was requested, 1 if usage was shown due to an error
    if [ "$1" = "help" ]; then
        exit 0
    else
        exit 1
    fi
}

TEST_DIR=""
FILE_SIZES_ARG=""
SINGLE_FILE="false"
MULTIPLE_SMALL_FILES="false"
VERBOSE="false"
QUIET="false"
LOCAL_DRIVE="false"

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--directory)
            TEST_DIR="$2"
            shift 2
            ;;
        -f|--file-sizes)
            FILE_SIZES_ARG="$2"
            shift 2
            ;;
        -s|--single)
            SINGLE_FILE="true"
            shift
            ;;
        -m|--multiple)
            MULTIPLE_SMALL_FILES="true"
            shift
            ;;
        -l|--local)
            LOCAL_DRIVE="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -h|--help)
            usage "help"
            ;;
        -q|--quiet)
            QUIET="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [ "$QUIET" = "true" ] && [ "$VERBOSE" = "true" ]; then
    echo "Error: Cannot be quiet and verbose at the same time"
    usage
fi

if [ "$SINGLE_FILE" = "false" ] && [ "$MULTIPLE_SMALL_FILES" = "false" ]; then
    echo "Error: Must run at least one test. Choose --single or --multiple"
    usage
fi

if [ -z "$TEST_DIR" ]; then
    echo "Error: Mount directory (-d) is required"
    usage
fi

# Add permission check before proceeding
if ! mkdir -p "$TEST_DIR" 2>/dev/null; then
    echo "Error: Cannot create directory in $TEST_DIR"
    echo "Please check permissions or run with sudo"
    exit 1
fi

# Test write permissions with a small file
TEST_WRITE_FILE="$TEST_DIR/.write_test"
if ! touch "$TEST_WRITE_FILE" 2>/dev/null; then
    echo "Error: Cannot write to $TEST_DIR"
    echo "Please check permissions or run with sudo"
    exit 1
fi
rm -f "$TEST_WRITE_FILE"

if [ -n "$FILE_SIZES_ARG" ]; then
    IFS=',' read -ra FILE_SIZES <<< "$FILE_SIZES_ARG"
else
    FILE_SIZES=(10M 50M 100M)
fi

SMALL_FILE_SIZE="1M"
TEST_FILE_PREFIX="speedtest"

TEST_PATH="${TEST_DIR}/speedtest_$(date +%s)"
SMALL_FILES_PATH="${TEST_PATH}/small_files"
if ! mkdir -p "$TEST_PATH" "$SMALL_FILES_PATH"; then
    echo "Error: Cannot create test directories in $TEST_DIR"
    echo "Please check permissions or run with sudo"
    exit 1
fi

if [ "$LOCAL_DRIVE" = "false" ]; then
    if ! mountpoint -q "$TEST_DIR"; then
        echo "Error: $TEST_DIR is not a valid mount point"
        echo "Please check if your NAS is properly mounted"
        echo "Use --local flag to skip this check for local/USB drives"
        exit 1
    fi
fi

declare -a read_speeds
declare -a write_speeds
declare -a small_read_speeds
declare -a small_write_speeds

info() {

    echo -e "\n=== TIME MEASUREMENTS EXPLAINED ==="
    echo "When you see time measurements in Linux, they show three values:"
    echo "real - This is the actual wall-clock time your operation took. This is what"
    echo "       you experience waiting for the operation to complete. For file transfers,"
    echo "       this is the most relevant number."
    echo ""
    echo "user - This is CPU time spent in user-space code. For file operations, this"
    echo "       is usually small because most work happens in the kernel or waiting"
    echo "       for the disk/network."
    echo ""
    echo "sys  - This is CPU time spent in kernel-space code. For file operations,"
    echo "       this includes time spent managing file systems and network protocols,"
    echo "       but not time spent waiting for the actual I/O."
    echo ""
    echo "For network file transfers:"
    echo "- High 'real' time but low 'user'+'sys' time usually indicates network/disk bottleneck"
    echo "- High 'sys' time might indicate protocol overhead or CPU-intensive compression"
    echo "- Small files typically show higher 'sys' time due to more file operations"
}

size_in_mb() {
    local size="$1"
    local mb

    if [[ $size == *"G"* ]]; then
        mb=${size%G}
        mb=$(echo "$mb * 1024" | bc)
    else
        mb=${size%M}
    fi

    printf "%d" "$mb"
}


test_transfer() {
    local description="$1"
    local src="$2"
    local dst="$3"
    local is_dir="$4"
    local size="$5"

    log_verbose "        Testing $description..." >&2

    if [ ! -e "$src" ]; then
        echo "0 0 0 0"  # Return zeros for all metrics
        return
    fi

    if [ "$is_dir" = "true" ]; then
        # Capture all three time values
        TIMEFORMAT='%R %U %S'
        timing=$( { time cp -r "$src" "$dst"; } 2>&1 )
    else
        TIMEFORMAT='%R %U %S'
        timing=$( { time cp "$src" "$dst"; } 2>&1 )
    fi

    # Parse the timing values
    read real user sys <<< "$timing"

    local mb=$(size_in_mb "$size")
    local speed=$(echo "scale=2; $mb / $real" | bc 2>/dev/null)
    if [[ $speed =~ ^[0-9]*\.?[0-9]*$ ]] && [ $(echo "$speed < 10000" | bc) -eq 1 ]; then
        # Return all values space-separated: speed user sys real
        echo "$speed $user $sys $real"
    else
        echo "0 0 0 0"
    fi
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "$1"
    fi
}

log() {
    if [ "$QUIET" = "false" ]; then
        echo "$1"
    fi
}

single_file_tests(){
    log "  > Starting Single File Tests"
    log_verbose "      Creating test files..."
    for size in "${FILE_SIZES[@]}"; do
        log_verbose "       - Generating ${size} test file..."
        local mb_size=$(size_in_mb "$size")
        dd if=/dev/urandom of="/tmp/${TEST_FILE_PREFIX}_${size}" bs=1M count="${mb_size%[A-Z]*}" 2>/dev/null
    done

    log_verbose "      Testing file writes..."
    for size in "${FILE_SIZES[@]}"; do
        speed="$(test_transfer "write speed with single ${size} file" \
            "/tmp/${TEST_FILE_PREFIX}_${size}" \
            "${TEST_PATH}/" \
            false \
            "$size")"
        write_speeds+=("$speed")
    done

    log_verbose "      Testing file reads..."
    for size in "${FILE_SIZES[@]}"; do
        speed="$(test_transfer "read speed with single ${size} file" \
            "${TEST_PATH}/${TEST_FILE_PREFIX}_${size}" \
            "/tmp/readtest_${size}" \
            false \
            "$size")"
        read_speeds+=("$speed")
    done
    log "      Single File Tests Complete"
}

multiple_small_files_tests(){
    log "  > Starting Multiple Small Files Tests"
    log_verbose "    Creating test files..."
    for size in "${FILE_SIZES[@]}"; do
        mb_size=$(size_in_mb "$size")
        log_verbose "    - Generating ${mb_size} files totaling ${size}..."
        mkdir -p "/tmp/small_${size}"

        for ((i=1; i<=${mb_size}; i++)); do
            dd if=/dev/urandom of="/tmp/small_${size}/file_${i}" bs=1M count=1 2>/dev/null
        done
    done



    log_verbose "  Testing writes..."

    for size in "${FILE_SIZES[@]}"; do
        speed="$(test_transfer "write speed with multiple files totaling ${size}" \
            "/tmp/small_${size}" \
            "${SMALL_FILES_PATH}/" \
            true \
            "$size")"
        small_write_speeds+=("$speed")

    done


    log_verbose "  Testing reads..."

    for size in "${FILE_SIZES[@]}"; do
        speed="$(test_transfer "read speed with multiple files totaling ${size}" \
            "${SMALL_FILES_PATH}/small_${size}" \
            "/tmp/readtest_small_${size}" \
            true \
            "$size")"
        small_read_speeds+=("$speed")

    done

    log "      Single File Tests Complete"
}

print_speed() {
    local speed="$1"
    local user="$2"
    local sys="$3"
    local real="$4"

    if [ "$VERBOSE" = "true" ]; then
        printf "%.2f MB/s (user: %.2f, sys: %.2f, real: %.2f)" "$speed" "$user" "$sys" "$real"
    else
        printf "%.2f MB/s" "$speed"
    fi
}

print_speed_row() {
    local test_id="$1"
    local type="$2"
    local size="$3"
    local num_files="$4"
    local speed="$5"
    local user="$6"
    local sys="$7"
    local real="$8"

    if [ "$VERBOSE" = "true" ]; then
        printf "%d\t%s\t%s\t%d\t%.2f MB/s\t%.2fs\t%.2fs\t%.2fs\n" \
            "$test_id" "$type" "$size" "$num_files" "$speed" "$real" "$user" "$sys"
    else
        printf "%d\t%s\t%s\t%d\t%.2f MB/s\t%.2fs\n" \
            "$test_id" "$type" "$size" "$num_files" "$speed" "$real"
    fi
}

print_multiple_file_results(){
    for i in "${!FILE_SIZES[@]}"; do
        size=${FILE_SIZES[$i]}
        local mb_size=$(size_in_mb "$size")
        num_files=$mb_size

        # Parse the space-separated values
        read small_read_speed small_read_user small_read_sys small_read_real <<< "${small_read_speeds[$i]:-0 0 0 0}"
        read small_write_speed small_write_user small_write_sys small_write_real <<< "${small_write_speeds[$i]:-0 0 0 0}"

        print_speed_row "$TEST_ID" "Read" "${FILE_SIZES[$i]}" "$num_files" \
            "$small_read_speed" "$small_read_user" "$small_read_sys" "$small_read_real"
        TEST_ID=$((TEST_ID+1))

        print_speed_row "$TEST_ID" "Write" "${FILE_SIZES[$i]}" "$num_files" \
            "$small_write_speed" "$small_write_user" "$small_write_sys" "$small_write_real"
        TEST_ID=$((TEST_ID+1))
    done
}

print_single_file_results(){
    for i in "${!FILE_SIZES[@]}"; do
        # Parse the space-separated values
        read read_speed read_user read_sys read_real <<< "${read_speeds[$i]:-0 0 0 0}"
        read write_speed write_user write_sys write_real <<< "${write_speeds[$i]:-0 0 0 0}"

        print_speed_row "$TEST_ID" "Read" "${FILE_SIZES[$i]}" "1" \
            "$read_speed" "$read_user" "$read_sys" "$read_real"
        TEST_ID=$((TEST_ID+1))

        print_speed_row "$TEST_ID" "Write" "${FILE_SIZES[$i]}" "1" \
            "$write_speed" "$write_user" "$write_sys" "$write_real"
        TEST_ID=$((TEST_ID+1))
    done
}

# LET'S GO

log "=== Running Tests ==="

if [ "$SINGLE_FILE" = "true" ]; then
    single_file_tests
fi

if [ "$MULTIPLE_SMALL_FILES" = "true" ]; then
    multiple_small_files_tests
fi

# All DONE

log -e "\n\n=== SUMMARY ==="
log -e "\n"
if [ "$VERBOSE" = "true" ]; then
    printf "TestId\tType\tSize\tFiles\tSpeed\t\tReal\tSys\tUser\n"
    printf "======================================================================\n"
else
    printf "TestId\tType\tSize\tFiles\tSpeed\t\tTime\n"
    printf "==========================================================\n"
fi

TEST_ID=0

if [ "$MULTIPLE_SMALL_FILES" = "true" ]; then
    print_multiple_file_results
fi

if [ "$SINGLE_FILE" = "true" ]; then
    print_single_file_results
fi

if [ "$VERBOSE" = "true" ]; then
    info
fi

# CLEANUP
log -e "\nCleaning up..."
rm -rf /tmp/${TEST_FILE_PREFIX}_* /tmp/readtest_* /tmp/small_* "/tmp/readtest_small_"*
rm -rf "$TEST_PATH"


log -e "\nTest complete!"