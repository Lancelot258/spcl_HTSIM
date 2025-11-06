#!/bin/bash

# Script to analyze and compare results from different load balancing algorithms
# Extracts key metrics from experiment output files

RESULTS_DIR="$(pwd)/results"
OUTPUT_SUMMARY="${RESULTS_DIR}/experiment_summary.txt"

echo "==========================================" > "$OUTPUT_SUMMARY"
echo "DCTCP Load Balancing Experiment Summary" >> "$OUTPUT_SUMMARY"
echo "==========================================" >> "$OUTPUT_SUMMARY"
echo "Generated: $(date)" >> "$OUTPUT_SUMMARY"
echo "" >> "$OUTPUT_SUMMARY"

# Algorithms tested
ALGOS=("ecmp" "reps" "oblivious")

for algo in "${ALGOS[@]}"; do
    OUTPUT_FILE="${RESULTS_DIR}/dctcp_${algo}.out"
    
    if [ ! -f "$OUTPUT_FILE" ]; then
        echo "Warning: Output file not found: $OUTPUT_FILE" >> "$OUTPUT_SUMMARY"
        continue
    fi
    
    echo "----------------------------------------" >> "$OUTPUT_SUMMARY"
    echo "Algorithm: $algo (uppercase)" >> "$OUTPUT_SUMMARY"
    echo "----------------------------------------" >> "$OUTPUT_SUMMARY"
    
    # Extract packet statistics
    echo "Packet Statistics:" >> "$OUTPUT_SUMMARY"
    grep -E "New:|Rtx:|RTS:|Bounced:|ACKs:|NACKs:" "$OUTPUT_FILE" | tail -1 >> "$OUTPUT_SUMMARY"
    
    # Extract ECN statistics
    echo "ECN Statistics:" >> "$OUTPUT_SUMMARY"
    grep "ECN Statistics:" "$OUTPUT_FILE" >> "$OUTPUT_SUMMARY"
    
    # Extract final DCTCP cwnd (if available)
    echo "Final DCTCP State:" >> "$OUTPUT_SUMMARY"
    grep "DCTCP start" "$OUTPUT_FILE" | tail -3 >> "$OUTPUT_SUMMARY"
    
    # Extract FCT information if available
    FCT_FILE="${RESULTS_DIR}/dctcp_${algo}_fct.txt"
    if [ -f "$FCT_FILE" ]; then
        echo "FCT Information:" >> "$OUTPUT_SUMMARY"
        grep -E "FCT:|Mean:|Median:|Throughput:" "$FCT_FILE" | head -5 >> "$OUTPUT_SUMMARY"
    fi
    
    echo "" >> "$OUTPUT_SUMMARY"
done

echo "==========================================" >> "$OUTPUT_SUMMARY"
echo "Summary saved to: $OUTPUT_SUMMARY" >> "$OUTPUT_SUMMARY"

# Display summary
cat "$OUTPUT_SUMMARY"

echo ""
echo "Detailed results are in: $RESULTS_DIR"
echo "  - dctcp_ecmp.out"
echo "  - dctcp_reps.out"
echo "  - dctcp_oblivious.out"

