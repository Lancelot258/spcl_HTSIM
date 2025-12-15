#!/bin/bash

# Analyze Final Results and Generate Comprehensive Report
# Extracts all three metrics and creates comparison tables

set -e

RESULTS_DIR=${1:-""}

if [ -z "$RESULTS_DIR" ]; then
    # Find latest results directory
    RESULTS_DIR=$(ls -td results_final_* 2>/dev/null | head -1)
fi

if [ -z "$RESULTS_DIR" ] || [ ! -d "$RESULTS_DIR" ]; then
    echo "Error: Results directory not found"
    echo "Usage: $0 [results_directory]"
    exit 1
fi

echo "=========================================="
echo "Final Results Analysis"
echo "=========================================="
echo "Results directory: $RESULTS_DIR"
echo ""

REPORT_FILE="$RESULTS_DIR/comprehensive_analysis.txt"

> "$REPORT_FILE"

echo "Comprehensive Results Analysis" >> "$REPORT_FILE"
echo "==============================" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Results directory: $RESULTS_DIR" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to extract metrics from a file
extract_metrics() {
    local file=$1
    local algo_name=$2
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Basic packet statistics
    if grep -q "^New:" "$file"; then
        total=$(grep "^New:" "$file" | tail -1 | awk '{print $2}')
        rtx=$(grep "^New:" "$file" | tail -1 | awk '{print $4}')
        nacks=$(grep "^New:" "$file" | tail -1 | awk '{print $12}')
        
        if [ -n "$total" ] && [ "$total" -gt 0 ]; then
            rtx_rate=$(echo "scale=4; $rtx * 100 / $total" | bc 2>/dev/null || echo "N/A")
            reordering_rate=$(echo "scale=4; $nacks * 100 / $total" | bc 2>/dev/null || echo "N/A")
            
            # Utilization balance
            cv=$(grep "Coefficient of Variation" "$file" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
            imbalance=$(grep "Imbalance ratio" "$file" | awk -F': ' '{print $2}' | head -1)
            
            echo "$algo_name|$total|$rtx|$rtx_rate|$nacks|$reordering_rate|$cv|$imbalance"
            return 0
        fi
    fi
    return 1
}

# Analyze each scenario
for scenario_dir in "$RESULTS_DIR"/*/; do
    if [ ! -d "$scenario_dir" ]; then
        continue
    fi
    
    scenario=$(basename "$scenario_dir")
    echo "Analyzing scenario: $scenario" >> "$REPORT_FILE"
    echo "===========================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Extract metrics for each algorithm
    echo "Metric Summary Table:" >> "$REPORT_FILE"
    echo "Algorithm | Total | RTX | RTX% | NACKs | Reorder% | CV | Imbalance" >> "$REPORT_FILE"
    echo "----------|-------|-----|------|-------|----------|----|-----------" >> "$REPORT_FILE"
    
    for algo in ecmp reps_ecn reps_conga; do
        algo_file="$scenario_dir/${algo}.out"
        
        if [ -f "$algo_file" ]; then
            case $algo in
                "ecmp") algo_name="ECMP" ;;
                "reps_ecn") algo_name="REPS (ECN)" ;;
                "reps_conga") algo_name="REPS-CONGA (MQL)" ;;
            esac
            
            metrics=$(extract_metrics "$algo_file" "$algo_name")
            if [ -n "$metrics" ]; then
                echo "$metrics" >> "$REPORT_FILE"
            fi
        fi
    done
    
    echo "" >> "$REPORT_FILE"
    
    # Detailed analysis
    echo "Detailed Analysis:" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    for algo in ecmp reps_ecn reps_conga; do
        algo_file="$scenario_dir/${algo}.out"
        
        if [ ! -f "$algo_file" ]; then
            continue
        fi
        
        case $algo in
            "ecmp") algo_name="ECMP" ;;
            "reps_ecn") algo_name="REPS (ECN)" ;;
            "reps_conga") algo_name="REPS-CONGA (MQL)" ;;
        esac
        
        echo "--- $algo_name ---" >> "$REPORT_FILE"
        
        # Metric 1: Queue Length (NACKs)
        nacks=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $12}' 2>/dev/null || echo "N/A")
        echo "1. Queue Length (NACKs): $nacks" >> "$REPORT_FILE"
        
        # Metric 2: Reordering Ratio
        total=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $2}' 2>/dev/null || echo "0")
        if [ -n "$nacks" ] && [ "$nacks" != "N/A" ] && [ -n "$total" ] && [ "$total" -gt 0 ]; then
            ratio=$(echo "scale=4; $nacks / $total" | bc 2>/dev/null || echo "N/A")
            percent=$(echo "scale=2; $ratio * 100" | bc 2>/dev/null || echo "N/A")
            echo "2. Packet Reordering Ratio: $ratio ($percent%)" >> "$REPORT_FILE"
        fi
        
        # Metric 3: Utilization Balance
        cv=$(grep "Coefficient of Variation" "$algo_file" | awk -F': ' '{print $2}' | awk '{print $1}' | head -1)
        imbalance=$(grep "Imbalance ratio" "$algo_file" | awk -F': ' '{print $2}' | head -1)
        
        if [ -n "$cv" ]; then
            echo "3. Link Utilization Balance:" >> "$REPORT_FILE"
            echo "   CV: $cv (lower = better)" >> "$REPORT_FILE"
            if [ -n "$imbalance" ]; then
                echo "   Imbalance ratio: $imbalance (closer to 1.0 = better)" >> "$REPORT_FILE"
            fi
        else
            echo "3. Link Utilization Balance: Not available" >> "$REPORT_FILE"
        fi
        
        echo "" >> "$REPORT_FILE"
    done
    
    echo "" >> "$REPORT_FILE"
done

# Generate comparison summary
echo "" >> "$REPORT_FILE"
echo "===========================================" >> "$REPORT_FILE"
echo "Cross-Scenario Comparison Summary" >> "$REPORT_FILE"
echo "===========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Print to console
cat "$REPORT_FILE"

echo ""
echo "=========================================="
echo "Analysis Complete"
echo "=========================================="
echo "Full report saved to: $REPORT_FILE"
echo ""

# Also create a CSV for easy import
CSV_FILE="$RESULTS_DIR/results_summary.csv"
echo "Scenario,Algorithm,Total_Packets,RTX,RTX_Rate,NACKs,Reorder_Rate,CV,Imbalance_Ratio" > "$CSV_FILE"

for scenario_dir in "$RESULTS_DIR"/*/; do
    if [ ! -d "$scenario_dir" ]; then
        continue
    fi
    
    scenario=$(basename "$scenario_dir")
    
    for algo in ecmp reps_ecn reps_conga; do
        algo_file="$scenario_dir/${algo}.out"
        
        if [ ! -f "$algo_file" ]; then
            continue
        fi
        
        case $algo in
            "ecmp") algo_name="ECMP" ;;
            "reps_ecn") algo_name="REPS_ECN" ;;
            "reps_conga") algo_name="REPS_CONGA" ;;
        esac
        
        metrics=$(extract_metrics "$algo_file" "$algo_name")
        if [ -n "$metrics" ]; then
            echo "$scenario,$metrics" >> "$CSV_FILE"
        fi
    done
done

echo "CSV summary saved to: $CSV_FILE"
echo ""

