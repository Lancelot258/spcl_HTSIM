#!/bin/bash

# Extract FCT for all load balancing algorithms

OUTPUT_DIR="results"
CONNECTION_MATRIX="congestion_scenario.cm"
FCT_SCRIPT="../task1/extract_fct_from_log.py"

echo "=========================================="
echo "Extracting Flow Completion Time (FCT)"
echo "=========================================="
echo ""

for algo in ecmp oblivious reps; do
    output_file="${OUTPUT_DIR}/${algo}_congestion.out"
    fct_output="${OUTPUT_DIR}/${algo}_fct.txt"
    
    if [ -f "$output_file" ]; then
        echo "Processing $algo..."
        python3 "$FCT_SCRIPT" "$output_file" "$CONNECTION_MATRIX" > "$fct_output" 2>&1
        echo "  FCT saved to: $fct_output"
    else
        echo "  Warning: $output_file not found"
    fi
done

echo ""
echo "=========================================="
echo "FCT Summary"
echo "=========================================="
echo ""

for algo in ecmp oblivious reps; do
    fct_file="${OUTPUT_DIR}/${algo}_fct.txt"
    if [ -f "$fct_file" ]; then
        echo "=== $algo ==="
        grep -E "Mean:|Median:|Min:|Max:|P50:|P95:|P99:" "$fct_file" | head -7
        echo ""
    fi
done


