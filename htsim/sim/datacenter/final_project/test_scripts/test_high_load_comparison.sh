#!/bin/bash

# High Load Comparison Test
# Purpose: Test if REPS can outperform ECMP under higher load conditions
# Hypothesis: Under higher load, dynamic load balancing should show advantages

set -e

EXECUTABLE="../../build/datacenter/htsim_uec"
TOPOLOGY="../topologies/topo_assignment2/fat_tree_128_4os.topo"

# HIGH LOAD parameters (more aggressive than normal tests)
NODES=128
SENDER_CC="dctcp"
QUEUE_TYPE="composite_ecn"
QUEUE_SIZE=20          # Small queue (was 50) - forces congestion
ECN_LOW=5              # Very early marking (was 10)
ECN_HIGH=15            # Tight threshold (was 40)
PATHS=256
CWND=25                # More aggressive (was 15)
MTU=1500
SEED=42

echo "=========================================="
echo "High Load Comparison Test"
echo "=========================================="
echo ""
echo "Hypothesis: Under higher load, REPS should outperform ECMP"
echo "because dynamic load balancing can avoid congested paths."
echo ""
echo "HIGH LOAD Parameters:"
echo "  - Queue Size: ${QUEUE_SIZE} packets (SMALL - forces congestion)"
echo "  - ECN: ${ECN_LOW}-${ECN_HIGH}% (TIGHT - early marking)"
echo "  - CWND: ${CWND} (AGGRESSIVE - more concurrent packets)"
echo ""
echo "Comparison with Normal Load:"
echo "  Normal: Queue=50, ECN=10-40%, CWND=15"
echo "  High:   Queue=20, ECN=5-15%,  CWND=25"
echo ""

# Function to run test and extract metrics
run_test() {
    local algo=$1
    local scenario=$2
    local matrix=$3
    local output_dir=$4
    local end_time=$5
    local use_conga=$6
    
    echo "=========================================="
    echo "Testing: $algo - $scenario (High Load)"
    echo "=========================================="
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
        -paths $PATHS \
        -cwnd $CWND \
        -mtu $MTU \
        -end $end_time \
        -seed $SEED"
    
    local output_file="${algo}.out"
    if [ "$use_conga" = "true" ]; then
        cmd="$cmd -use_conga"
        output_file="reps_conga.out"
    fi
    
    eval $cmd > "$output_dir/$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
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
        echo "✗ Failed"
    fi
    echo ""
}

# Scenario 1: Mixed Traffic (High Load)
SCENARIO1="Mixed Traffic"
MATRIX1="three_way_test_scenario.cm"
OUTPUT_DIR1="results_high_load_mixed"
END_TIME1=80000  # Longer for high load
mkdir -p "$OUTPUT_DIR1"

echo "=========================================="
echo "SCENARIO 1: Mixed Traffic (High Load)"
echo "=========================================="
echo "Expected: Higher retransmission rates due to aggressive parameters"
echo "Question: Does REPS outperform ECMP under high load?"
echo ""

run_test "ecmp" "$SCENARIO1" "$MATRIX1" "$OUTPUT_DIR1" "$END_TIME1" "false"
run_test "reps" "$SCENARIO1" "$MATRIX1" "$OUTPUT_DIR1" "$END_TIME1" "false"
if [ -f "$OUTPUT_DIR1/reps.out" ]; then
    mv "$OUTPUT_DIR1/reps.out" "$OUTPUT_DIR1/reps_ecn.out"
fi
run_test "reps" "$SCENARIO1" "$MATRIX1" "$OUTPUT_DIR1" "$END_TIME1" "true"

# Scenario 2: Severe Incast (High Load)
SCENARIO2="Severe Incast"
MATRIX2="severe_incast_scenario.cm"
OUTPUT_DIR2="results_high_load_incast"
END_TIME2=120000
mkdir -p "$OUTPUT_DIR2"

echo "=========================================="
echo "SCENARIO 2: Severe Incast (High Load)"
echo "=========================================="
echo "Expected: Very high retransmission rates (>30%)"
echo "Question: Can REPS avoid hash collisions better than ECMP?"
echo ""

run_test "ecmp" "$SCENARIO2" "$MATRIX2" "$OUTPUT_DIR2" "$END_TIME2" "false"
run_test "reps" "$SCENARIO2" "$MATRIX2" "$OUTPUT_DIR2" "$END_TIME2" "false"
if [ -f "$OUTPUT_DIR2/reps.out" ]; then
    mv "$OUTPUT_DIR2/reps.out" "$OUTPUT_DIR2/reps_ecn.out"
fi
run_test "reps" "$SCENARIO2" "$MATRIX2" "$OUTPUT_DIR2" "$END_TIME2" "true"

# Summary
echo "=========================================="
echo "HIGH LOAD TEST COMPLETE"
echo "=========================================="
echo ""
echo "Results directories:"
echo "  - Mixed Traffic: $OUTPUT_DIR1/"
echo "  - Severe Incast: $OUTPUT_DIR2/"
echo ""
echo "Comparison Table:"
echo ""

# Extract and display results
echo "SCENARIO 1: Mixed Traffic (High Load)"
echo "--------------------------------------"
for algo in ecmp reps_ecn reps_conga; do
    if [ -f "$OUTPUT_DIR1/${algo}.out" ]; then
        new_pkts=$(grep "^New:" "$OUTPUT_DIR1/${algo}.out" | tail -1 | awk '{print $2}')
        rtx=$(grep "^New:" "$OUTPUT_DIR1/${algo}.out" | tail -1 | awk '{print $4}')
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            printf "  %-12s: %6s retransmissions (%5.2f%%)\n" "$algo" "$rtx" "$rtx_rate"
        fi
    fi
done

echo ""
echo "SCENARIO 2: Severe Incast (High Load)"
echo "--------------------------------------"
for algo in ecmp reps_ecn reps_conga; do
    if [ -f "$OUTPUT_DIR2/${algo}.out" ]; then
        new_pkts=$(grep "^New:" "$OUTPUT_DIR2/${algo}.out" | tail -1 | awk '{print $2}')
        rtx=$(grep "^New:" "$OUTPUT_DIR2/${algo}.out" | tail -1 | awk '{print $4}')
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            printf "  %-12s: %6s retransmissions (%5.2f%%)\n" "$algo" "$rtx" "$rtx_rate"
        fi
    fi
done

echo ""
echo "=========================================="
echo "Analysis:"
echo "  - Compare with normal load results"
echo "  - Check if REPS advantage increases under high load"
echo "=========================================="

