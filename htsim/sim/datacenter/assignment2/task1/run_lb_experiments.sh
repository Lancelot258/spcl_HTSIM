#!/bin/bash

# Experiment script to run DCTCP with different load balancing algorithms
# Based on parameters from run_test.sh

# Parameters Setting (from run_test.sh)
EXECUTABLE="../../htsim_uec"
TOPOLOGY="../../topologies/topo_assignment2/fat_tree_128_4os.topo"
CONNECTION_MATRIX="../../connection_matrices/cm_assignment2/one.cm"

# Output Directory
OUTPUT_DIR="$(pwd)/results"
mkdir -p "$OUTPUT_DIR"

# Load Balancing Algorithms to test
LB_ALGOS=("ecmp" "reps" "oblivious")

# Check if executable exists
if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: Executable not found: $EXECUTABLE"
    echo "Please compile the project first"
    exit 1
fi

# Check topology and connection matrix files
if [ ! -f "$TOPOLOGY" ]; then
    echo "Error: Topology file not found: $TOPOLOGY"
    exit 1
fi

if [ ! -f "$CONNECTION_MATRIX" ]; then
    echo "Error: Connection matrix file not found: $CONNECTION_MATRIX"
    exit 1
fi

echo "=========================================="
echo "DCTCP Load Balancing Experiments"
echo "=========================================="
echo "Topology: $TOPOLOGY"
echo "Connection Matrix: $CONNECTION_MATRIX"
echo "Output Directory: $OUTPUT_DIR"
echo "Algorithms: ${LB_ALGOS[@]}"
echo ""

# Run experiments for each load balancing algorithm
for algo in "${LB_ALGOS[@]}"; do
    echo "----------------------------------------"
    echo "Running experiment with algorithm: $algo"
    echo "----------------------------------------"
    
    # Output file name
    OUTPUT_FILE="${OUTPUT_DIR}/dctcp_${algo}.out"
    
    # Run the experiment with parameters from run_test.sh
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
        -cwnd 1 \
        -mtu 1500 \
        -end 1000 \
        -log flow_events \
        -seed 0 \
        > "$OUTPUT_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ Experiment completed: $OUTPUT_FILE"
        
        # Calculate FCT for this experiment
        FCT_OUTPUT="${OUTPUT_DIR}/dctcp_${algo}_fct.txt"
        echo "  Calculating FCT..."
        python3 extract_fct_from_log.py "$OUTPUT_FILE" "$CONNECTION_MATRIX" > "$FCT_OUTPUT" 2>&1
        if [ $? -eq 0 ]; then
            echo "  ✓ FCT analysis saved to: dctcp_${algo}_fct.txt"
        else
            echo "  ⚠ FCT calculation had issues, check $FCT_OUTPUT"
        fi
    else
        echo "✗ Experiment failed: $OUTPUT_FILE"
    fi
    
    echo ""
done

echo "=========================================="
echo "All experiments completed!"
echo "Results saved in: $OUTPUT_DIR"
echo "=========================================="

