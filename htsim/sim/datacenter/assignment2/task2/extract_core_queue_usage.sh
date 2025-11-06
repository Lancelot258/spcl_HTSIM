#!/bin/bash

# Extract core switch queue usage from logout.dat
# This script parses the binary log file and extracts queue usage data for core switches

LOG_FILE="logout.dat"
IDMAP_FILE="idmap.txt"
OUTPUT_DIR="$(pwd)/results"
OUTPUT_FILE="$OUTPUT_DIR/core_queue_usage.txt"
SUMMARY_FILE="$OUTPUT_DIR/core_queue_usage_summary.txt"

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

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Parse queue usage data with ASCII output
echo "Parsing queue usage data..."
echo "Filtering for Core switches (Switch_Core)..."
echo ""

# Extract QUEUE_APPROX events for core switches
# queue_usage logging uses QUEUE_APPROX events
$PARSE_OUTPUT "$LOG_FILE" -ascii -idmap "$IDMAP_FILE" 2>&1 | \
    grep -E "QUEUE_APPROX.*Switch_Core" > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "✓ Queue usage data extracted successfully"
    echo ""
    echo "Output saved to: $OUTPUT_FILE"
    echo ""
    
    # Count total events
    TOTAL_EVENTS=$(wc -l < "$OUTPUT_FILE")
    echo "Total queue usage events: $TOTAL_EVENTS"
    echo ""
    
    # Extract unique core switch IDs
    echo "Core switches found:"
    grep -o "Switch_Core_[0-9]*" "$OUTPUT_FILE" | sort -u | while read switch_name; do
        switch_id=$(grep "$switch_name" "$IDMAP_FILE" | awk '{print $1}')
        event_count=$(grep "$switch_name" "$OUTPUT_FILE" | wc -l)
        echo "  $switch_name (ID: $switch_id): $event_count events"
    done
    echo ""
    
    # Generate summary
    echo "Generating summary..."
    echo "==========================================" > "$SUMMARY_FILE"
    echo "Core Switch Queue Usage Summary" >> "$SUMMARY_FILE"
    echo "==========================================" >> "$SUMMARY_FILE"
    echo "Generated: $(date)" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
    echo "Total events: $TOTAL_EVENTS" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
    
    # Extract statistics for each core switch
    grep -o "Switch_Core_[0-9]*" "$OUTPUT_FILE" | sort -u | while read switch_name; do
        switch_id=$(grep "$switch_name" "$IDMAP_FILE" | awk '{print $1}')
        echo "----------------------------------------" >> "$SUMMARY_FILE"
        echo "Switch: $switch_name (ID: $switch_id)" >> "$SUMMARY_FILE"
        echo "----------------------------------------" >> "$SUMMARY_FILE"
        
        # Extract queue usage values for this switch
        # Format: Time Type QUEUE_APPROX ID X Ev RANGE LastQ Y MinQ Z MaxQ W Name SwitchName
        grep "$switch_name" "$OUTPUT_FILE" | awk '
        {
            # Parse queue usage values from QUEUE_APPROX format
            # Find LastQ, MinQ, MaxQ fields
            lastq = 0
            minq = 0
            maxq = 0
            for (i=1; i<=NF; i++) {
                if ($i == "LastQ") lastq = $(i+1)
                if ($i == "MinQ") minq = $(i+1)
                if ($i == "MaxQ") maxq = $(i+1)
            }
            if (NR == 1) {
                min_lastq = lastq
                max_lastq = lastq
                min_minq = minq
                max_minq = minq
                min_maxq = maxq
                max_maxq = maxq
                sum_lastq = lastq
                sum_minq = minq
                sum_maxq = maxq
            } else {
                if (lastq < min_lastq) min_lastq = lastq
                if (lastq > max_lastq) max_lastq = lastq
                if (minq < min_minq) min_minq = minq
                if (minq > max_minq) max_minq = minq
                if (maxq < min_maxq) min_maxq = maxq
                if (maxq > max_maxq) max_maxq = maxq
                sum_lastq += lastq
                sum_minq += minq
                sum_maxq += maxq
            }
            count++
        }
        END {
            if (count > 0) {
                printf "  LastQ: min=%.0f max=%.0f avg=%.0f bytes\n", min_lastq, max_lastq, sum_lastq/count
                printf "  MinQ:  min=%.0f max=%.0f avg=%.0f bytes\n", min_minq, max_minq, sum_minq/count
                printf "  MaxQ:  min=%.0f max=%.0f avg=%.0f bytes\n", min_maxq, max_maxq, sum_maxq/count
                printf "  Samples: %d\n", count
            }
        }' >> "$SUMMARY_FILE"
        echo "" >> "$SUMMARY_FILE"
    done
    
    echo "Summary saved to: $SUMMARY_FILE"
    echo ""
    echo "First 20 lines of queue usage data:"
    echo "----------------------------------------"
    head -20 "$OUTPUT_FILE"
    echo ""
    echo "To view all queue usage data:"
    echo "  cat $OUTPUT_FILE"
    echo ""
    echo "To view summary:"
    echo "  cat $SUMMARY_FILE"
else
    echo "✗ Failed to parse queue usage data"
    exit 1
fi

