#!/bin/bash

# Script to parse switch queue data from logout.dat using parse_output

LOG_FILE="logout.dat"
IDMAP_FILE="idmap.txt"
OUTPUT_FILE="results/switch_queue_data.txt"

# Check if log files exist
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: $LOG_FILE not found"
    echo "Please run run_switch_queue_logging.sh first"
    exit 1
fi

if [ ! -f "$IDMAP_FILE" ]; then
    echo "Error: $IDMAP_FILE not found"
    exit 1
fi

# Find parse_output executable
PARSE_OUTPUT=""
if [ -f "../../../../build/parse_output" ]; then
    PARSE_OUTPUT="../../../../build/parse_output"
elif [ -f "../../../build/parse_output" ]; then
    PARSE_OUTPUT="../../../build/parse_output"
elif [ -f "../../../../htsim/sim/build/parse_output" ]; then
    PARSE_OUTPUT="../../../../htsim/sim/build/parse_output"
else
    echo "parse_output not found. Attempting to compile..."
    cd ../../../..
    if [ -d "build" ]; then
        cd build
        make parse_output 2>&1
        if [ $? -eq 0 ] && [ -f "parse_output" ]; then
            PARSE_OUTPUT="$(pwd)/parse_output"
            cd ../../htsim/sim/datacenter/assignment2/task3
        else
            echo "Failed to compile parse_output"
            exit 1
        fi
    else
        echo "Build directory not found. Please compile the project first."
        echo "Run: cd htsim/sim && mkdir -p build && cd build && cmake .. && make parse_output"
        exit 1
    fi
fi

echo "Using parse_output: $PARSE_OUTPUT"
echo ""

# Parse queue data with ASCII output
echo "Parsing switch queue data..."
echo "Filtering for Spine switches (Switch_UpperPod) and Leaf switches (Switch_LowerPod)..."
echo ""

mkdir -p results

# Extract QUEUE_APPROX events for switches
$PARSE_OUTPUT "$LOG_FILE" -ascii -idmap "$IDMAP_FILE" 2>&1 | \
    grep -E "QUEUE_APPROX.*Switch_(Upper|Lower)Pod" > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "✓ Queue data extracted successfully"
    echo ""
    echo "Output saved to: $OUTPUT_FILE"
    echo ""
    echo "First 20 lines of queue data:"
    echo "----------------------------------------"
    head -20 "$OUTPUT_FILE"
    echo ""
    echo "Summary:"
    echo "  Total queue events: $(wc -l < "$OUTPUT_FILE")"
    echo ""
    echo "Spine switch events (Switch_UpperPod):"
    grep "Switch_UpperPod" "$OUTPUT_FILE" | wc -l | xargs echo "  "
    echo ""
    echo "Leaf switch events (Switch_LowerPod):"
    grep "Switch_LowerPod" "$OUTPUT_FILE" | wc -l | xargs echo "  "
    echo ""
    echo "To view all queue data:"
    echo "  cat $OUTPUT_FILE"
    echo ""
    echo "To filter only Spine switches:"
    echo "  grep 'Switch_UpperPod' $OUTPUT_FILE"
else
    echo "✗ Failed to parse queue data"
    exit 1
fi


