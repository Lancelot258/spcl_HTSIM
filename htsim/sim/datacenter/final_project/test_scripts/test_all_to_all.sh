#!/bin/bash

# All-to-All Traffic Scenario: 32 nodes communicate with each other
# Purpose: Test load balancing under uniform, high-volume, distributed traffic

set -e

EXECUTABLE="../../build/datacenter/htsim_uec"
TOPOLOGY="../topologies/topo_assignment2/fat_tree_128_4os.topo"
CONNECTION_MATRIX="all_to_all_scenario.cm"

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
END_TIME=150000      # Longer duration for 992 flows
SEED=42

OUTPUT_DIR="results_all_to_all"
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "All-to-All Traffic Scenario Test"
echo "=========================================="
echo ""
echo "Scenario Design:"
echo "  - 32 nodes (0-31)"
echo "  - Each node → all other 31 nodes"
echo "  - Total: 32×31 = 992 flows"
echo "  - Flow size: 1.4-3.0 MB (variable)"
echo "  - Start time: slightly staggered (100-195 μs)"
echo ""
echo "Characteristics:"
echo "  - Uniform traffic distribution"
echo "  - High total volume (~2 GB)"
echo "  - Tests network-wide congestion"
echo "  - Multiple paths heavily utilized"
echo ""
echo "Expected Behavior:"
echo "  - ECMP: Static hashing, may cause imbalance"
echo "  - REPS: Dynamic, but per-packet reordering"
echo "  - REPS-CONGA: MQL feedback under uniform load"
echo ""
echo "Test Configuration:"
echo "  - Queue: ${QUEUE_SIZE} packets"
echo "  - ECN: ${ECN_LOW}-${ECN_HIGH}%"
echo "  - Duration: ${END_TIME} μs"
echo ""

# Test 1: ECMP
echo "=========================================="
echo "Test 1: ECMP (Static Hash-based)"
echo "=========================================="
echo "Expected: Predictable, may have hash collisions"
echo ""
echo "Running..."

$EXECUTABLE \
    -nodes $NODES \
    -topo "$TOPOLOGY" \
    -tm "$CONNECTION_MATRIX" \
    -sender_cc_algo $SENDER_CC \
    -load_balancing_algo ecmp \
    -queue_type $QUEUE_TYPE \
    -q $QUEUE_SIZE \
    -ecn $ECN_LOW $ECN_HIGH \
    -cwnd $CWND \
    -mtu $MTU \
    -end $END_TIME \
    -seed $SEED \
    > "$OUTPUT_DIR/ecmp.out" 2>&1

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ ECMP test completed"
    
    NEW_PKTS=$(grep "^New:" "$OUTPUT_DIR/ecmp.out" | tail -1 | awk '{print $2}')
    RTX=$(grep "^New:" "$OUTPUT_DIR/ecmp.out" | tail -1 | awk '{print $4}')
    NACKS=$(grep "^New:" "$OUTPUT_DIR/ecmp.out" | tail -1 | awk '{print $12}')
    
    echo "  Results: Packets=$NEW_PKTS, Retrans=$RTX, NACKs=$NACKS"
    
    if [ ! -z "$NEW_PKTS" ] && [ ! -z "$RTX" ] && [ "$NEW_PKTS" -gt 0 ]; then
        RTX_RATE=$(awk "BEGIN {printf \"%.3f\", ($RTX / $NEW_PKTS * 100)}")
        echo "  Retransmission rate: ${RTX_RATE}%"
    fi
    
    if [ -f "logout.dat" ]; then
        mv logout.dat "$OUTPUT_DIR/ecmp_logout.dat"
    fi
else
    echo "✗ ECMP test failed (exit code $EXIT_CODE)"
    tail -20 "$OUTPUT_DIR/ecmp.out"
fi
echo ""

# Test 2: REPS
echo "=========================================="
echo "Test 2: REPS (Dynamic ECN-based)"
echo "=========================================="
echo "Expected: Dynamic adaptation, but reordering overhead"
echo ""
echo "Running..."

$EXECUTABLE \
    -nodes $NODES \
    -topo "$TOPOLOGY" \
    -tm "$CONNECTION_MATRIX" \
    -sender_cc_algo $SENDER_CC \
    -load_balancing_algo reps \
    -queue_type $QUEUE_TYPE \
    -q $QUEUE_SIZE \
    -ecn $ECN_LOW $ECN_HIGH \
    -paths $PATHS \
    -cwnd $CWND \
    -mtu $MTU \
    -end $END_TIME \
    -seed $SEED \
    > "$OUTPUT_DIR/reps.out" 2>&1

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ REPS test completed"
    
    NEW_PKTS=$(grep "^New:" "$OUTPUT_DIR/reps.out" | tail -1 | awk '{print $2}')
    RTX=$(grep "^New:" "$OUTPUT_DIR/reps.out" | tail -1 | awk '{print $4}')
    NACKS=$(grep "^New:" "$OUTPUT_DIR/reps.out" | tail -1 | awk '{print $12}')
    
    echo "  Results: Packets=$NEW_PKTS, Retrans=$RTX, NACKs=$NACKS"
    
    if [ ! -z "$NEW_PKTS" ] && [ ! -z "$RTX" ] && [ "$NEW_PKTS" -gt 0 ]; then
        RTX_RATE=$(awk "BEGIN {printf \"%.3f\", ($RTX / $NEW_PKTS * 100)}")
        echo "  Retransmission rate: ${RTX_RATE}%"
    fi
    
    if [ -f "logout.dat" ]; then
        mv logout.dat "$OUTPUT_DIR/reps_logout.dat"
    fi
else
    echo "✗ REPS test failed (exit code $EXIT_CODE)"
    tail -20 "$OUTPUT_DIR/reps.out"
fi
echo ""

# Test 3: REPS-CONGA
echo "=========================================="
echo "Test 3: REPS-CONGA (MQL 3-bit)"
echo "=========================================="
echo "Expected: Test MQL under uniform distributed load"
echo ""
echo "Running..."

$EXECUTABLE \
    -nodes $NODES \
    -topo "$TOPOLOGY" \
    -tm "$CONNECTION_MATRIX" \
    -sender_cc_algo $SENDER_CC \
    -load_balancing_algo reps \
    -use_conga \
    -queue_type $QUEUE_TYPE \
    -q $QUEUE_SIZE \
    -ecn $ECN_LOW $ECN_HIGH \
    -paths $PATHS \
    -cwnd $CWND \
    -mtu $MTU \
    -end $END_TIME \
    -seed $SEED \
    > "$OUTPUT_DIR/reps_conga.out" 2>&1

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ REPS-CONGA test completed"
    
    NEW_PKTS=$(grep "^New:" "$OUTPUT_DIR/reps_conga.out" | tail -1 | awk '{print $2}')
    RTX=$(grep "^New:" "$OUTPUT_DIR/reps_conga.out" | tail -1 | awk '{print $4}')
    NACKS=$(grep "^New:" "$OUTPUT_DIR/reps_conga.out" | tail -1 | awk '{print $12}')
    
    echo "  Results: Packets=$NEW_PKTS, Retrans=$RTX, NACKs=$NACKS"
    
    if [ ! -z "$NEW_PKTS" ] && [ ! -z "$RTX" ] && [ "$NEW_PKTS" -gt 0 ]; then
        RTX_RATE=$(awk "BEGIN {printf \"%.3f\", ($RTX / $NEW_PKTS * 100)}")
        echo "  Retransmission rate: ${RTX_RATE}%"
    fi
    
    if [ -f "logout.dat" ]; then
        mv logout.dat "$OUTPUT_DIR/reps_conga_logout.dat"
    fi
else
    echo "✗ REPS-CONGA test failed (exit code $EXIT_CODE)"
    tail -20 "$OUTPUT_DIR/reps_conga.out"
fi
echo ""

# Performance Comparison
echo "=========================================="
echo "All-to-All Performance Comparison"
echo "=========================================="
echo ""

ECMP_OUT="$OUTPUT_DIR/ecmp.out"
REPS_OUT="$OUTPUT_DIR/reps.out"
CONGA_OUT="$OUTPUT_DIR/reps_conga.out"

if [ -f "$ECMP_OUT" ] && [ -f "$REPS_OUT" ] && [ -f "$CONGA_OUT" ]; then
    ECMP_NEW=$(grep "^New:" "$ECMP_OUT" | tail -1 | awk '{print $2}')
    ECMP_RTX=$(grep "^New:" "$ECMP_OUT" | tail -1 | awk '{print $4}')
    ECMP_NACKS=$(grep "^New:" "$ECMP_OUT" | tail -1 | awk '{print $12}')
    
    REPS_NEW=$(grep "^New:" "$REPS_OUT" | tail -1 | awk '{print $2}')
    REPS_RTX=$(grep "^New:" "$REPS_OUT" | tail -1 | awk '{print $4}')
    REPS_NACKS=$(grep "^New:" "$REPS_OUT" | tail -1 | awk '{print $12}')
    
    CONGA_NEW=$(grep "^New:" "$CONGA_OUT" | tail -1 | awk '{print $2}')
    CONGA_RTX=$(grep "^New:" "$CONGA_OUT" | tail -1 | awk '{print $4}')
    CONGA_NACKS=$(grep "^New:" "$CONGA_OUT" | tail -1 | awk '{print $12}')
    
    if [ ! -z "$ECMP_NEW" ] && [ ! -z "$REPS_NEW" ] && [ ! -z "$CONGA_NEW" ]; then
        ECMP_RTX_RATE=$(awk "BEGIN {printf \"%.3f\", ($ECMP_RTX / $ECMP_NEW * 100)}")
        REPS_RTX_RATE=$(awk "BEGIN {printf \"%.3f\", ($REPS_RTX / $REPS_NEW * 100)}")
        CONGA_RTX_RATE=$(awk "BEGIN {printf \"%.3f\", ($CONGA_RTX / $CONGA_NEW * 100)}")
        
        # Calculate relative performance
        ECMP_VS_REPS=$(awk "BEGIN {printf \"%.2f\", (($ECMP_RTX - $REPS_RTX) / $ECMP_RTX * 100)}")
        REPS_VS_CONGA=$(awk "BEGIN {printf \"%.2f\", (($REPS_RTX - $CONGA_RTX) / $REPS_RTX * 100)}")
        ECMP_VS_CONGA=$(awk "BEGIN {printf \"%.2f\", (($ECMP_RTX - $CONGA_RTX) / $ECMP_RTX * 100)}")
        
        echo "┌─────────────────────┬──────────┬────────────┬───────────┬──────────────┐"
        echo "│ Algorithm           │ Packets  │ Retrans    │ Rate      │ vs Previous  │"
        echo "├─────────────────────┼──────────┼────────────┼───────────┼──────────────┤"
        printf "│ %-19s │ %8s │ %10s │ %8s%% │ %12s │\n" "ECMP (baseline)" "$ECMP_NEW" "$ECMP_RTX" "$ECMP_RTX_RATE" "baseline"
        printf "│ %-19s │ %8s │ %10s │ %8s%% │ %11s%% │\n" "REPS (ECN 2-bit)" "$REPS_NEW" "$REPS_RTX" "$REPS_RTX_RATE" "$ECMP_VS_REPS"
        printf "│ %-19s │ %8s │ %10s │ %8s%% │ %11s%% │\n" "REPS-CONGA (MQL)" "$CONGA_NEW" "$CONGA_RTX" "$CONGA_RTX_RATE" "$REPS_VS_CONGA"
        echo "└─────────────────────┴──────────┴────────────┴───────────┴──────────────┘"
        echo ""
        
        echo "Analysis:"
        echo ""
        echo "Scenario: All-to-All (992 flows, ~2GB total)"
        echo ""
        
        # Determine best performer
        if (( $(echo "$ECMP_RTX <= $REPS_RTX" | bc -l 2>/dev/null || echo 1) )); then
            if (( $(echo "$ECMP_RTX <= $CONGA_RTX" | bc -l 2>/dev/null || echo 1) )); then
                echo "🏆 Best: ECMP"
                echo "   → Static hashing performs well under uniform load"
                echo "   → Flow-level consistency minimizes reordering"
            else
                echo "🏆 Best: REPS-CONGA"
                echo "   → MQL provides benefit in this scenario"
            fi
        else
            if (( $(echo "$REPS_RTX <= $CONGA_RTX" | bc -l 2>/dev/null || echo 1) )); then
                echo "🏆 Best: REPS (ECN)"
                echo "   → Dynamic adaptation helps under uniform load"
                echo "   → ECN feedback sufficient"
            else
                echo "🏆 Best: REPS-CONGA"
                echo "   → MQL enhancement provides clear benefit"
            fi
        fi
        echo ""
        
        # ECMP vs REPS
        if (( $(echo "$ECMP_VS_REPS > 0" | bc -l 2>/dev/null || echo 0) )); then
            echo "✅ REPS improves upon ECMP by ${ECMP_VS_REPS}%"
        elif (( $(echo "$ECMP_VS_REPS == 0" | bc -l 2>/dev/null || echo 0) )); then
            echo "➡️  REPS performs equivalently to ECMP"
        else
            LOSS=$(awk "BEGIN {printf \"%.2f\", -($ECMP_VS_REPS)}")
            echo "⚠️  ECMP outperforms REPS by ${LOSS}%"
            echo "   → Per-packet reordering overhead exceeds benefit"
        fi
        echo ""
        
        # REPS vs CONGA
        if (( $(echo "$REPS_VS_CONGA > 0" | bc -l 2>/dev/null || echo 0) )); then
            echo "✅ MQL improves upon REPS by ${REPS_VS_CONGA}%"
        elif (( $(echo "$REPS_VS_CONGA == 0" | bc -l 2>/dev/null || echo 0) )); then
            echo "➡️  MQL performs equivalently to REPS"
        else
            LOSS=$(awk "BEGIN {printf \"%.2f\", -($REPS_VS_CONGA)}")
            echo "⚠️  MQL performs worse than REPS by ${LOSS}%"
        fi
        
        echo ""
        echo "Overall ECMP → REPS-CONGA: ${ECMP_VS_CONGA}%"
        
    else
        echo "⚠️  Could not extract metrics for comparison"
    fi
else
    echo "⚠️  Missing output files"
fi
echo ""

echo "=========================================="
echo "Test Completed!"
echo "=========================================="
echo ""
echo "Output directory: $OUTPUT_DIR/"
echo ""
echo "Key Observations:"
echo "  - All-to-all tests network-wide behavior"
echo "  - 992 flows create uniform, distributed load"
echo "  - Good stress test for load balancing algorithms"
echo "  - Results complement incast & mixed scenarios"
echo ""

