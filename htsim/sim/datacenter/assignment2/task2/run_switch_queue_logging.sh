#!/bin/bash

# Task 3: Run simulation and log core switch queue usage
# This script runs the simulation with queue usage logging enabled
# Parameters are based on run_lb_experiments.sh

# Parameters Setting (matching run_lb_experiments.sh)
EXECUTABLE="../../htsim_uec"
TOPOLOGY="../../topologies/topo_assignment2/fat_tree_128_4os.topo"
CONNECTION_MATRIX="../../connection_matrices/cm_assignment2/one.cm"
LOAD_BALANCING_ALGO="ecmp"  # ecmp, reps, oblivious

# Output Directory
OUTPUT_DIR="$(pwd)/results"
mkdir -p "$OUTPUT_DIR"

# Output files
OUTPUT_FILE="$OUTPUT_DIR/simulation.out"
LOG_FILE="logout.dat"

# Check files
if [ ! -f "$TOPOLOGY" ]; then
    echo "Error: Topology file not found $TOPOLOGY"
    exit 1
fi

if [ ! -f "$CONNECTION_MATRIX" ]; then
    echo "Error: Connection matrix file not found $CONNECTION_MATRIX"
    exit 1
fi

echo "=========================================="
echo "Task 3: Core Switch Queue Usage Logging"
echo "=========================================="
echo "Topology: $TOPOLOGY"
echo "Connection Matrix: $CONNECTION_MATRIX"
echo "Output Directory: $OUTPUT_DIR"
echo "Load Balancing Algorithm: $LOAD_BALANCING_ALGO"
echo ""
echo "This simulation will log queue usage for core switches."
echo "For Fat-tree topology (3-tier), Core switches are in Tier 2."
echo ""
echo "Running simulation with queue usage logging enabled..."
echo ""

# Run simulation with queue usage logging
# Note: Clock progress dots (....|....) are normal output, not errors
# They indicate simulation is running. The simulation will complete when done.
echo "Simulation running... (progress dots are normal, simulation will complete)"
$EXECUTABLE \
    -nodes 128 \
    -topo "$TOPOLOGY" \
    -tm "$CONNECTION_MATRIX" \
    -sender_cc_algo dctcp \
    -load_balancing_algo $LOAD_BALANCING_ALGO \
    -queue_type composite_ecn \
    -q 100 \
    -ecn 20 80 \
    -paths 2000 \
    -cwnd 1 \
    -mtu 1500 \
    -end 100 \
    -log switch \
    -logtime_us 100 \
    -seed 0 \
    > "$OUTPUT_FILE" 2>&1

# Check result
if [ $? -eq 0 ]; then
    echo "✓ Simulation Completed"
    echo ""
    echo "Log files generated:"
    echo "  - $OUTPUT_FILE (standard output)"
    echo "  - $LOG_FILE (binary log with queue usage data)"
    echo ""
    echo "Note: Queue usage data is in binary format in $LOG_FILE"
    echo "Use extract_core_queue_usage.sh to extract core switch queue usage."
    echo ""
    echo "To extract core switch queue usage:"
    echo "  bash extract_core_queue_usage.sh"
else
    echo "✗ Simulation Failed, please check $OUTPUT_FILE"
    exit 1
fi

echo ""
echo "=========================================="

