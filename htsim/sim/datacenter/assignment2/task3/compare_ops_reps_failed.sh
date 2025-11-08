#!/bin/bash

# Compare OPS and REPS under link failure degradation
# This script runs simulations for both algorithms and extracts FCT

# Parameters Setting
EXECUTABLE="../../../build/datacenter/htsim_uec"
TOPOLOGY="../../topologies/topo_assignment2/fat_tree_128_4os.topo"
CONNECTION_MATRIX="../../connection_matrices/cm_assignment2/one.cm"

# Number of failed links (reduced to 50% of total links)
# For fat_tree_128_4os: 
# - 8 pods, 4 Agg switches per pod = 32 Agg switches
# - Each Agg has 1 uplink to Core (radix_up = 1)
# - Total AGG->Core links = 32
# - 50% = 16 links
NUM_FAILED_LINKS=24  # Approximately 50% of links

# Output directory
OUTPUT_DIR="results"
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "Comparing OPS vs REPS under Link Failure"
echo "=========================================="
echo "Topology: $TOPOLOGY"
echo "Connection Matrix: $CONNECTION_MATRIX"
echo "Failed Links: $NUM_FAILED_LINKS (reduced to 25% speed)"
echo ""

# Function to run simulation and extract FCT
run_simulation() {
    local algo=$1
    local output_file="$OUTPUT_DIR/${algo}_failed_${NUM_FAILED_LINKS}.out"
    local log_file="logout_${algo}.dat"
    
    echo "Running simulation for: $algo"
    echo "----------------------------------------"
    
    $EXECUTABLE \
        -nodes 128 \
        -topo "$TOPOLOGY" \
        -tm "$CONNECTION_MATRIX" \
        -sender_cc_algo dctcp \
        -load_balancing_algo "$algo" \
        -queue_type composite_ecn \
        -q 100 \
        -ecn 20 80 \
        -paths 200 \
        -cwnd 10 \
        -mtu 1500 \
        -end 1000 \
        -failed $NUM_FAILED_LINKS \
        -log flow_events \
        -seed 0 \
        > "$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ Simulation completed for $algo"
        
        # Extract FCT from output
        if [ -f "$log_file" ]; then
            mv "$log_file" "${OUTPUT_DIR}/logout_${algo}.dat"
        fi
        
        # Try to extract FCT from output file
        echo ""
        echo "Extracting FCT for $algo..."
        python3 ../../task1/extract_fct_from_log.py "$output_file" "$CONNECTION_MATRIX" > "${OUTPUT_DIR}/${algo}_fct.txt" 2>&1
        
        echo "Results saved to: ${OUTPUT_DIR}/${algo}_failed_${NUM_FAILED_LINKS}.out"
        echo "FCT analysis saved to: ${OUTPUT_DIR}/${algo}_fct.txt"
    else
        echo "✗ Simulation failed for $algo"
    fi
    echo ""
}

# Run simulations for both algorithms
run_simulation "oblivious"
run_simulation "reps"

# Compare results
echo "=========================================="
echo "FCT Comparison Summary"
echo "=========================================="
echo ""

if [ -f "${OUTPUT_DIR}/oblivious_fct.txt" ]; then
    echo "=== OPS (Oblivious) FCT ==="
    cat "${OUTPUT_DIR}/oblivious_fct.txt"
    echo ""
fi

if [ -f "${OUTPUT_DIR}/reps_fct.txt" ]; then
    echo "=== REPS FCT ==="
    cat "${OUTPUT_DIR}/reps_fct.txt"
    echo ""
fi

echo "=========================================="
echo "Comparison complete!"
echo "=========================================="
echo ""
echo "To analyze results:"
echo "  - Check ${OUTPUT_DIR}/oblivious_fct.txt"
echo "  - Check ${OUTPUT_DIR}/reps_fct.txt"
echo ""

