#!/bin/bash

# Run Final Experiments with Fixed Code (No Excessive Logging)
# Uses test_strict_priority_comprehensive.sh as base but ensures we use latest code

set -e

EXECUTABLE="../../build/datacenter/htsim_uec"
TOPOLOGY="../topologies/topo_assignment2/fat_tree_128_4os.topo"

# Test parameters
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

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results_final_fixed_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

echo "=========================================="
echo "Final Experiments with Fixed Code"
echo "=========================================="
echo ""
echo "Timestamp: $TIMESTAMP"
echo "Results directory: $RESULTS_DIR"
echo ""
echo "✅ Using fixed code (no excessive DCTCP logging)"
echo "✅ Will collect all three metrics including Utilization Balance"
echo ""
echo "This will run 9 tests (3 scenarios × 3 algorithms)"
echo "Estimated time: 15-30 minutes with fixed code"
echo ""

# Function to run a test
run_test() {
    local algo=$1
    local scenario=$2
    local matrix=$3
    local output_file=$4
    local end_time=$5
    
    echo "Running: $algo - $scenario"
    
    local cmd_args=(
        -nodes $NODES
        -topo "$TOPOLOGY"
        -tm "$matrix"
        -sender_cc_algo $SENDER_CC
        -load_balancing_algo $algo
        -queue_type $QUEUE_TYPE
        -q $QUEUE_SIZE
        -ecn $ECN_LOW $ECN_HIGH
        -cwnd $CWND
        -mtu $MTU
        -end $end_time
        -seed $SEED
    )
    
    # Add -use_conga flag for REPS-CONGA
    if [ "$algo" = "reps" ] && [ "$scenario" = "MQL" ]; then
        cmd_args+=(-use_conga)
    fi
    
    "$EXECUTABLE" "${cmd_args[@]}" > "$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
        # Check if output file has reasonable size and contains expected content
        size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
        if [ "$size" -gt 1000 ] && grep -q "^New:" "$output_file" 2>/dev/null; then
            echo "  ✅ Completed (size: $(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B"))"
            return 0
        else
            echo "  ⚠️  Completed but output seems incomplete (size: ${size}B)"
            return 1
        fi
    else
        echo "  ❌ Failed with exit code $?"
        return 1
    fi
}

# Scenario 1: Mixed Traffic
SCENARIO1="Mixed Traffic"
MATRIX1="three_way_test_scenario.cm"
OUTPUT_DIR1="$RESULTS_DIR/mixed_traffic"
END_TIME1=50000
mkdir -p "$OUTPUT_DIR1"

echo "=========================================="
echo "SCENARIO 1: Mixed Traffic"
echo "=========================================="
echo "Description: 118 flows with diverse patterns"
echo ""

run_test "ecmp" "$SCENARIO1" "$MATRIX1" "$OUTPUT_DIR1/ecmp.out" "$END_TIME1"
run_test "reps" "$SCENARIO1" "$MATRIX1" "$OUTPUT_DIR1/reps_ecn.out" "$END_TIME1"
# Rename reps.out to reps_ecn.out if it exists
if [ -f "$OUTPUT_DIR1/reps.out" ] && [ ! -f "$OUTPUT_DIR1/reps_ecn.out" ]; then
    mv "$OUTPUT_DIR1/reps.out" "$OUTPUT_DIR1/reps_ecn.out"
fi
run_test "reps" "MQL" "$MATRIX1" "$OUTPUT_DIR1/reps_conga.out" "$END_TIME1"
if [ -f "$OUTPUT_DIR1/reps.out" ]; then
    mv "$OUTPUT_DIR1/reps.out" "$OUTPUT_DIR1/reps_conga.out"
fi

echo ""

# Scenario 2: Severe Incast
SCENARIO2="Severe Incast"
MATRIX2="severe_incast_scenario.cm"
OUTPUT_DIR2="$RESULTS_DIR/severe_incast"
END_TIME2=100000
mkdir -p "$OUTPUT_DIR2"

echo "=========================================="
echo "SCENARIO 2: Severe Incast"
echo "=========================================="
echo "Description: 64 sources → 1 destination, 320MB total"
echo ""

run_test "ecmp" "$SCENARIO2" "$MATRIX2" "$OUTPUT_DIR2/ecmp.out" "$END_TIME2"
run_test "reps" "$SCENARIO2" "$MATRIX2" "$OUTPUT_DIR2/reps_ecn.out" "$END_TIME2"
if [ -f "$OUTPUT_DIR2/reps.out" ] && [ ! -f "$OUTPUT_DIR2/reps_ecn.out" ]; then
    mv "$OUTPUT_DIR2/reps.out" "$OUTPUT_DIR2/reps_ecn.out"
fi
run_test "reps" "MQL" "$MATRIX2" "$OUTPUT_DIR2/reps_conga.out" "$END_TIME2"
if [ -f "$OUTPUT_DIR2/reps.out" ]; then
    mv "$OUTPUT_DIR2/reps.out" "$OUTPUT_DIR2/reps_conga.out"
fi

echo ""

# Scenario 3: All-to-All
SCENARIO3="All-to-All"
MATRIX3="all_to_all_scenario.cm"
OUTPUT_DIR3="$RESULTS_DIR/all_to_all"
END_TIME3=150000
mkdir -p "$OUTPUT_DIR3"

echo "=========================================="
echo "SCENARIO 3: All-to-All"
echo "=========================================="
echo "Description: 32 nodes × 31 destinations = 992 flows"
echo ""

run_test "ecmp" "$SCENARIO3" "$MATRIX3" "$OUTPUT_DIR3/ecmp.out" "$END_TIME3"
run_test "reps" "$SCENARIO3" "$MATRIX3" "$OUTPUT_DIR3/reps_ecn.out" "$END_TIME3"
if [ -f "$OUTPUT_DIR3/reps.out" ] && [ ! -f "$OUTPUT_DIR3/reps_ecn.out" ]; then
    mv "$OUTPUT_DIR3/reps.out" "$OUTPUT_DIR3/reps_ecn.out"
fi
run_test "reps" "MQL" "$MATRIX3" "$OUTPUT_DIR3/reps_conga.out" "$END_TIME3"
if [ -f "$OUTPUT_DIR3/reps.out" ]; then
    mv "$OUTPUT_DIR3/reps.out" "$OUTPUT_DIR3/reps_conga.out"
fi

echo ""

echo "=========================================="
echo "All Experiments Completed"
echo "=========================================="
echo "Results saved to: $RESULTS_DIR"
echo ""
echo "Now extracting three metrics..."

# Extract metrics for each scenario
for scenario_dir in "$RESULTS_DIR"/*/; do
    if [ -d "$scenario_dir" ]; then
        scenario=$(basename "$scenario_dir")
        echo "Extracting metrics for: $scenario"
        if [ -f "extract_three_metrics.sh" ]; then
            bash extract_three_metrics.sh "$scenario_dir" > "$scenario_dir/metrics_extraction.log" 2>&1
        fi
    fi
done

echo ""
echo "Running comprehensive analysis..."
if [ -f "analyze_final_results.sh" ]; then
    bash analyze_final_results.sh "$RESULTS_DIR" > "$RESULTS_DIR/analysis_output.log" 2>&1
fi

echo ""
echo "=========================================="
echo "Data Collection Complete"
echo "=========================================="
echo "Results directory: $RESULTS_DIR"
echo ""
echo "Generated files:"
echo "  - Individual scenario metrics: $RESULTS_DIR/*/three_metrics_extracted.txt"
echo "  - Comprehensive analysis: $RESULTS_DIR/comprehensive_analysis.txt"
echo "  - CSV summary: $RESULTS_DIR/results_summary.csv"

