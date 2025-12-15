#!/bin/bash

# Analyze results from strict priority implementation tests

set -e

echo "=========================================="
echo "Strict Priority Implementation - Results Analysis"
echo "=========================================="
echo ""

analyze_scenario() {
    local scenario=$1
    local dir=$2
    
    echo "SCENARIO: $scenario"
    echo "Directory: $dir"
    echo "--------------------------------------"
    
    if [ ! -d "$dir" ]; then
        echo "⚠ Directory not found: $dir"
        echo ""
        return
    fi
    
    # ECMP
    if [ -f "$dir/ecmp.out" ]; then
        local new_pkts=$(grep "^New:" "$dir/ecmp.out" | tail -1 | awk '{print $2}')
        local rtx=$(grep "^New:" "$dir/ecmp.out" | tail -1 | awk '{print $4}')
        local nacks=$(grep "^New:" "$dir/ecmp.out" | tail -1 | awk '{print $12}')
        
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            local rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            printf "ECMP:        %6s retransmissions (%5.2f%%) [NACKs: %s]\n" "$rtx" "$rtx_rate" "$nacks"
        fi
    fi
    
    # REPS (ECN)
    if [ -f "$dir/reps_ecn.out" ]; then
        local new_pkts=$(grep "^New:" "$dir/reps_ecn.out" | tail -1 | awk '{print $2}')
        local rtx=$(grep "^New:" "$dir/reps_ecn.out" | tail -1 | awk '{print $4}')
        local nacks=$(grep "^New:" "$dir/reps_ecn.out" | tail -1 | awk '{print $12}')
        
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            local rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            printf "REPS (ECN):  %6s retransmissions (%5.2f%%) [NACKs: %s]\n" "$rtx" "$rtx_rate" "$nacks"
        fi
    elif [ -f "$dir/reps.out" ]; then
        # Fallback to reps.out if reps_ecn.out doesn't exist
        local new_pkts=$(grep "^New:" "$dir/reps.out" | tail -1 | awk '{print $2}')
        local rtx=$(grep "^New:" "$dir/reps.out" | tail -1 | awk '{print $4}')
        local nacks=$(grep "^New:" "$dir/reps.out" | tail -1 | awk '{print $12}')
        
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            local rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            printf "REPS (ECN):  %6s retransmissions (%5.2f%%) [NACKs: %s]\n" "$rtx" "$rtx_rate" "$nacks"
        fi
    fi
    
    # REPS-CONGA (MQL)
    if [ -f "$dir/reps_conga.out" ]; then
        local new_pkts=$(grep "^New:" "$dir/reps_conga.out" | tail -1 | awk '{print $2}')
        local rtx=$(grep "^New:" "$dir/reps_conga.out" | tail -1 | awk '{print $4}')
        local nacks=$(grep "^New:" "$dir/reps_conga.out" | tail -1 | awk '{print $12}')
        
        if [ -n "$new_pkts" ] && [ "$new_pkts" != "0" ]; then
            local rtx_rate=$(echo "scale=3; $rtx * 100 / $new_pkts" | bc)
            printf "REPS-CONGA:  %6s retransmissions (%5.2f%%) [NACKs: %s]\n" "$rtx" "$rtx_rate" "$nacks"
        fi
    fi
    
    echo ""
}

# Analyze all scenarios
analyze_scenario "Mixed Traffic" "results_strict_priority_mixed"
analyze_scenario "Severe Incast" "results_strict_priority_incast"
analyze_scenario "All-to-All" "results_strict_priority_all_to_all"

echo "=========================================="
echo "Analysis Complete"
echo "=========================================="

