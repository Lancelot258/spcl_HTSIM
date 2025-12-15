#!/bin/bash

# Comprehensive Test with Strict Priority Implementation
# Tests: Mixed Traffic, Severe Incast, All-to-All
# Algorithms: ECMP, REPS (ECN), REPS-CONGA (MQL with strict priority)

set -e

EXECUTABLE="../../build/datacenter/htsim_uec"
TOPOLOGY="../topologies/topo_assignment2/fat_tree_128_4os.topo"

# Unified test parameters
NODES=128
SENDER_CC="dctcp"
QUEUE_TYPE="composite_ecn"
QUEUE_SIZE=50
ECN_LOW=10
ECN_HIGH=40
PATHS=256
CWND=15
MTU=1500
SEED=42

echo "=========================================="
echo "Strict Priority MQL Implementation Test"
echo "=========================================="
echo ""
echo "New Implementation Features:"
echo "  - Strict priority path selection"
echo "  - MQL-level grouping (0-7)"
echo "  - Random selection from lowest available MQL group"
echo "  - Automatic grouping maintenance"
echo ""
echo "Test Scenarios:"
echo "  1. Mixed Traffic (118 flows)"
echo "  2. Severe Incast (64→1, 320MB)"
echo "  3. All-to-All (32 nodes, 992 flows)"
echo ""
echo "Algorithms:"
echo "  - ECMP: Static hash-based"
echo "  - REPS (ECN): Binary ECN feedback"
echo "  - REPS-CONGA (MQL): 3-bit MQL with strict priority"
echo ""

# Function to run a test
run_test() {
    local algo=$1
    local scenario=$2
    local matrix=$3
    local output_dir=$4
    local end_time=$5
    local desc=$6
    
    echo "=========================================="
    echo "Testing: $algo - $scenario"
    echo "=========================================="
    echo "$desc"
    echo ""
    echo "Running..."
    
    local cmd="$EXECUTABLE \
        -nodes $NODES \
        -topo \"$TOPOLOGY\" \
        -tm \"$matrix\" \
        -sender_cc_algo $SENDER_CC \
        -load_balancing_algo $algo \
        -queue_type $QUEUE_TYPE \
        -q $QUEUE_SIZE \
        -ecn $ECN_LOW $ECN_HIGH \
        -cwnd $CWND \
        -mtu $MTU \
        -end $end_time \
        -seed $SEED"
    
    local output_file="${algo}.out"
    if [ "$algo" = "reps" ] && [ "$scenario" = "MQL" ]; then
        cmd="$cmd -use_conga"
        output_file="reps_conga.out"
    fi
    
    eval $cmd > "$output_dir/$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
        # Extract metrics
        local new_pkts=$(grep "^New:" "$output_dir/$output_file" | tail -1 | awk '{print $2}')
        local rtx=$(grep "^New:" "$output_dir/$output_file" | tail -1 | awk '{print $4}')
        local nacks=$(grep "^New:" "$output_dir/$output_file" | tail -1 | awk '{print $12}')
        
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            local rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            echo "✓ Completed"
            echo "  New packets: $new_pkts"
            echo "  Retransmissions: $rtx ($rtx_rate%)"
            echo "  NACKs: $nacks"
        else
            echo "⚠ Completed but no data packets found"
        fi
    else
        echo "✗ Failed with exit code $?"
    fi
    echo ""
}

# Scenario 1: Mixed Traffic
SCENARIO1="Mixed Traffic"
MATRIX1="three_way_test_scenario.cm"
OUTPUT_DIR1="results_strict_priority_mixed"
END_TIME1=50000
mkdir -p "$OUTPUT_DIR1"

echo "=========================================="
echo "SCENARIO 1: Mixed Traffic"
echo "=========================================="
echo "Description: 118 flows with diverse patterns"
echo "  - Many-to-one, one-to-many, point-to-point"
echo "  - Flow sizes: 0.5-10 MB"
echo "  - Staggered start times"
echo ""

run_test "ecmp" "$SCENARIO1" "$MATRIX1" "$OUTPUT_DIR1" "$END_TIME1" "ECMP: Static hash-based routing"
run_test "reps" "$SCENARIO1" "$MATRIX1" "$OUTPUT_DIR1" "$END_TIME1" "REPS: ECN-based dynamic recycling"
# Rename reps.out to reps_ecn.out for clarity
if [ -f "$OUTPUT_DIR1/reps.out" ]; then
    mv "$OUTPUT_DIR1/reps.out" "$OUTPUT_DIR1/reps_ecn.out"
fi
run_test "reps" "MQL" "$MATRIX1" "$OUTPUT_DIR1" "$END_TIME1" "REPS-CONGA: MQL with strict priority"

# Scenario 2: Severe Incast
SCENARIO2="Severe Incast"
MATRIX2="severe_incast_scenario.cm"
OUTPUT_DIR2="results_strict_priority_incast"
END_TIME2=100000
mkdir -p "$OUTPUT_DIR2"

echo "=========================================="
echo "SCENARIO 2: Severe Incast"
echo "=========================================="
echo "Description: 64 sources → 1 destination"
echo "  - Each flow: 5 MB"
echo "  - Total: 320 MB to single node"
echo "  - Simultaneous start"
echo ""

run_test "ecmp" "$SCENARIO2" "$MATRIX2" "$OUTPUT_DIR2" "$END_TIME2" "ECMP: Static hash-based routing"
run_test "reps" "$SCENARIO2" "$MATRIX2" "$OUTPUT_DIR2" "$END_TIME2" "REPS: ECN-based dynamic recycling"
run_test "reps" "MQL" "$MATRIX2" "$OUTPUT_DIR2" "$END_TIME2" "REPS-CONGA: MQL with strict priority"

# Scenario 3: All-to-All
SCENARIO3="All-to-All"
MATRIX3="all_to_all_scenario.cm"
OUTPUT_DIR3="results_strict_priority_all_to_all"
END_TIME3=150000
mkdir -p "$OUTPUT_DIR3"

echo "=========================================="
echo "SCENARIO 3: All-to-All"
echo "=========================================="
echo "Description: 32 nodes × 31 destinations = 992 flows"
echo "  - Flow sizes: 1.4-3.0 MB (variable)"
echo "  - Total volume: ~2 GB"
echo "  - Uniform distribution"
echo ""

run_test "ecmp" "$SCENARIO3" "$MATRIX3" "$OUTPUT_DIR3" "$END_TIME3" "ECMP: Static hash-based routing"
run_test "reps" "$SCENARIO3" "$MATRIX3" "$OUTPUT_DIR3" "$END_TIME3" "REPS: ECN-based dynamic recycling"
run_test "reps" "MQL" "$MATRIX3" "$OUTPUT_DIR3" "$END_TIME3" "REPS-CONGA: MQL with strict priority"

# Summary
echo "=========================================="
echo "TEST COMPLETE - Summary"
echo "=========================================="
echo ""
echo "Results directories:"
echo "  - Mixed Traffic: $OUTPUT_DIR1/"
echo "  - Severe Incast: $OUTPUT_DIR2/"
echo "  - All-to-All: $OUTPUT_DIR3/"
echo ""
echo "Generating comparison summary..."

# Generate summary
SUMMARY_FILE="results_strict_priority_summary.txt"
cat > "$SUMMARY_FILE" <<EOF
Strict Priority MQL Implementation - Test Results
==================================================

Test Date: $(date)
Implementation: Strict Priority Path Selection

SCENARIO 1: Mixed Traffic (118 flows)
--------------------------------------
EOF

for algo in ecmp reps; do
    if [ -f "$OUTPUT_DIR1/${algo}.out" ]; then
        new_pkts=$(grep "^New:" "$OUTPUT_DIR1/${algo}.out" | tail -1 | awk '{print $2}')
        rtx=$(grep "^New:" "$OUTPUT_DIR1/${algo}.out" | tail -1 | awk '{print $4}')
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            echo "$algo: $rtx retransmissions ($rtx_rate%)" >> "$SUMMARY_FILE"
        fi
    fi
done

if [ -f "$OUTPUT_DIR1/reps.out" ] && [ -f "$OUTPUT_DIR1/reps.out" ]; then
    # Check if MQL test exists (should be in reps.out if -use_conga was used)
    # Actually, we need a separate file for MQL
    if [ -f "$OUTPUT_DIR1/reps_mql.out" ]; then
        new_pkts=$(grep "^New:" "$OUTPUT_DIR1/reps_mql.out" | tail -1 | awk '{print $2}')
        rtx=$(grep "^New:" "$OUTPUT_DIR1/reps_mql.out" | tail -1 | awk '{print $4}')
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            echo "reps-conga: $rtx retransmissions ($rtx_rate%)" >> "$SUMMARY_FILE"
        fi
    fi
fi

echo "" >> "$SUMMARY_FILE"
echo "SCENARIO 2: Severe Incast (64→1)" >> "$SUMMARY_FILE"
echo "--------------------------------------" >> "$SUMMARY_FILE"

for algo in ecmp reps; do
    if [ -f "$OUTPUT_DIR2/${algo}.out" ]; then
        new_pkts=$(grep "^New:" "$OUTPUT_DIR2/${algo}.out" | tail -1 | awk '{print $2}')
        rtx=$(grep "^New:" "$OUTPUT_DIR2/${algo}.out" | tail -1 | awk '{print $4}')
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            echo "$algo: $rtx retransmissions ($rtx_rate%)" >> "$SUMMARY_FILE"
        fi
    fi
done

echo "" >> "$SUMMARY_FILE"
echo "SCENARIO 3: All-to-All (992 flows)" >> "$SUMMARY_FILE"
echo "--------------------------------------" >> "$SUMMARY_FILE"

for algo in ecmp reps; do
    if [ -f "$OUTPUT_DIR3/${algo}.out" ]; then
        new_pkts=$(grep "^New:" "$OUTPUT_DIR3/${algo}.out" | tail -1 | awk '{print $2}')
        rtx=$(grep "^New:" "$OUTPUT_DIR3/${algo}.out" | tail -1 | awk '{print $4}')
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            echo "$algo: $rtx retransmissions ($rtx_rate%)" >> "$SUMMARY_FILE"
        fi
    fi
done

cat "$SUMMARY_FILE"
echo ""
echo "Full summary saved to: $SUMMARY_FILE"
echo ""
echo "=========================================="
echo "All tests completed!"
echo "=========================================="

