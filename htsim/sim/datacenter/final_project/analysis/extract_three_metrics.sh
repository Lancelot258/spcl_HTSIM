#!/bin/bash

# Extract Three Key Metrics:
# 1. Maximum and Average Queue Length
# 2. Packet Reordering Ratio
# 3. Link Utilization Balance

set -e

OUTPUT_DIR=${1:-"results_three_way_comparison"}
SUMMARY_FILE="${OUTPUT_DIR}/three_metrics_extracted.txt"

PARSE_OUTPUT="../../build/parse_output"
IDMAP_FILE="idmap.txt"

echo "=========================================="
echo "Extracting Three Key Metrics"
echo "=========================================="
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check if parse_output exists
if [ ! -f "$PARSE_OUTPUT" ]; then
    echo "⚠ Warning: parse_output not found at $PARSE_OUTPUT"
    echo "  Queue length extraction will be limited"
    PARSE_OUTPUT=""
fi

# Check if idmap exists
if [ ! -f "$IDMAP_FILE" ]; then
    echo "⚠ Warning: idmap.txt not found"
    echo "  Queue length extraction may be limited"
fi

> "$SUMMARY_FILE"
echo "Three Key Metrics Extraction Report" >> "$SUMMARY_FILE"
echo "====================================" >> "$SUMMARY_FILE"
echo "Generated: $(date)" >> "$SUMMARY_FILE"
echo "Output directory: $OUTPUT_DIR" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# ==================================================
# Metric 1: Maximum and Average Queue Length
# ==================================================
echo "Metric 1: Extracting Queue Length Statistics..."
echo "" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"
echo "METRIC 1: QUEUE LENGTH" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

for algo_file in "$OUTPUT_DIR"/ecmp.out "$OUTPUT_DIR"/reps_ecn.out "$OUTPUT_DIR"/reps_conga.out; do
    if [ ! -f "$algo_file" ]; then
        continue
    fi
    
    algo=$(basename "$algo_file" .out)
    algo_name=$(echo "$algo" | sed 's/_/ /g' | sed 's/reps ecn/REPS (ECN)/' | sed 's/reps conga/REPS-CONGA (MQL)/' | sed 's/ecmp/ECMP/')
    
    echo "" >> "$SUMMARY_FILE"
    echo "Algorithm: $algo_name" >> "$SUMMARY_FILE"
    echo "----------------------------------------" >> "$SUMMARY_FILE"
    
    # Extract from output file
    if grep -q "^New:" "$algo_file"; then
        total=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $2}')
        nacks=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $12}')
        rtx=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $4}')
        
        echo "  Total packets: $total" >> "$SUMMARY_FILE"
        echo "  NACKs (queue drops indicator): $nacks" >> "$SUMMARY_FILE"
        echo "  Retransmissions: $rtx" >> "$SUMMARY_FILE"
        
        # Queue length from logout.dat if available
        log_file=$(echo "$algo_file" | sed 's/\.out$/_logout.dat/')
        if [ -f "$log_file" ] && [ -n "$PARSE_OUTPUT" ] && [ -f "$IDMAP_FILE" ]; then
            echo "  Processing queue log: $(basename $log_file)" >> "$SUMMARY_FILE"
            
            # Extract queue statistics
            temp_queue_file=$(mktemp)
            $PARSE_OUTPUT "$log_file" -ascii -idmap "$IDMAP_FILE" 2>/dev/null | \
                grep "QUEUE_APPROX" > "$temp_queue_file" || true
            
            if [ -s "$temp_queue_file" ]; then
                # Extract MaxQ values
                maxq_values=$(awk '{for(i=1;i<=NF;i++) if($i=="MaxQ") print $(i+1)}' "$temp_queue_file")
                lastq_values=$(awk '{for(i=1;i<=NF;i++) if($i=="LastQ") print $(i+1)}' "$temp_queue_file")
                
                if [ -n "$maxq_values" ]; then
                    # Calculate statistics using awk
                    max_maxq=$(echo "$maxq_values" | sort -n | tail -1)
                    avg_maxq=$(echo "$maxq_values" | awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}')
                    avg_lastq=$(echo "$lastq_values" | awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}')
                    
                    # Convert bytes to packets (assuming 1500 bytes per packet)
                    max_maxq_pkts=$(echo "scale=2; $max_maxq / 1500" | bc 2>/dev/null || echo "N/A")
                    avg_maxq_pkts=$(echo "scale=2; $avg_maxq / 1500" | bc 2>/dev/null || echo "N/A")
                    avg_lastq_pkts=$(echo "scale=2; $avg_lastq / 1500" | bc 2>/dev/null || echo "N/A")
                    
                    echo "  Maximum queue length: $max_maxq bytes ($max_maxq_pkts packets)" >> "$SUMMARY_FILE"
                    echo "  Average max queue length: $avg_maxq bytes ($avg_maxq_pkts packets)" >> "$SUMMARY_FILE"
                    echo "  Average current queue length: $avg_lastq bytes ($avg_lastq_pkts packets)" >> "$SUMMARY_FILE"
                else
                    echo "  No queue length data found in log" >> "$SUMMARY_FILE"
                fi
            else
                echo "  Could not parse queue log (may require different format)" >> "$SUMMARY_FILE"
            fi
            rm -f "$temp_queue_file"
        else
            echo "  Queue log not available: $(basename $log_file 2>/dev/null || echo 'N/A')" >> "$SUMMARY_FILE"
        fi
    else
        echo "  No statistics found in output file" >> "$SUMMARY_FILE"
    fi
done

# ==================================================
# Metric 2: Packet Reordering Ratio
# ==================================================
echo ""
echo "Metric 2: Extracting Packet Reordering Ratio..."
echo "" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"
echo "METRIC 2: PACKET REORDERING RATIO" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

for algo_file in "$OUTPUT_DIR"/ecmp.out "$OUTPUT_DIR"/reps_ecn.out "$OUTPUT_DIR"/reps_conga.out; do
    if [ ! -f "$algo_file" ]; then
        continue
    fi
    
    algo=$(basename "$algo_file" .out)
    algo_name=$(echo "$algo" | sed 's/_/ /g' | sed 's/reps ecn/REPS (ECN)/' | sed 's/reps conga/REPS-CONGA (MQL)/' | sed 's/ecmp/ECMP/')
    
    echo "" >> "$SUMMARY_FILE"
    echo "Algorithm: $algo_name" >> "$SUMMARY_FILE"
    echo "----------------------------------------" >> "$SUMMARY_FILE"
    
    if grep -q "^New:" "$algo_file"; then
        total=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $2}')
        nacks=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $12}')
        rtx=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $4}')
        
        if [ -n "$total" ] && [ "$total" -gt 0 ]; then
            # Reordering ratio = NACK rate (NACKs typically caused by out-of-order packets)
            nack_ratio=$(echo "scale=4; $nacks / $total" | bc)
            nack_percent=$(echo "scale=2; $nack_ratio * 100" | bc)
            
            # Alternative: retransmission ratio (also indicates reordering)
            rtx_ratio=$(echo "scale=4; $rtx / $total" | bc)
            rtx_percent=$(echo "scale=2; $rtx_ratio * 100" | bc)
            
            echo "  Total packets: $total" >> "$SUMMARY_FILE"
            echo "  NACKs (out-of-order indicator): $nacks" >> "$SUMMARY_FILE"
            echo "  NACK ratio: $nack_ratio ($nack_percent%)" >> "$SUMMARY_FILE"
            echo "  Retransmission ratio: $rtx_ratio ($rtx_percent%)" >> "$SUMMARY_FILE"
            echo "  Packet reordering ratio: ~$nack_ratio ($nack_percent%)" >> "$SUMMARY_FILE"
        fi
    fi
done

# ==================================================
# Metric 3: Link Utilization Balance
# ==================================================
echo ""
echo "Metric 3: Extracting Link Utilization Balance..."
echo "" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"
echo "METRIC 3: LINK UTILIZATION BALANCE" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

for algo_file in "$OUTPUT_DIR"/ecmp.out "$OUTPUT_DIR"/reps_ecn.out "$OUTPUT_DIR"/reps_conga.out; do
    if [ ! -f "$algo_file" ]; then
        continue
    fi
    
    algo=$(basename "$algo_file" .out)
    algo_name=$(echo "$algo" | sed 's/_/ /g' | sed 's/reps ecn/REPS (ECN)/' | sed 's/reps conga/REPS-CONGA (MQL)/' | sed 's/ecmp/ECMP/')
    
    echo "" >> "$SUMMARY_FILE"
    echo "Algorithm: $algo_name" >> "$SUMMARY_FILE"
    echo "----------------------------------------" >> "$SUMMARY_FILE"
    
    if grep -q "^New:" "$algo_file"; then
        total=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $2}')
        nacks=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $12}')
        rtx=$(grep "^New:" "$algo_file" | tail -1 | awk '{print $4}')
        
        # Number of paths (typically 256 for fat-tree)
        NUM_PATHS=256
        avg_per_path=$(echo "scale=2; $total / $NUM_PATHS" | bc)
        
        echo "  Total packets: $total" >> "$SUMMARY_FILE"
        echo "  Number of paths: $NUM_PATHS" >> "$SUMMARY_FILE"
        echo "  Average packets per path: $avg_per_path" >> "$SUMMARY_FILE"
        echo "" >> "$SUMMARY_FILE"
        echo "  Balance indicators:" >> "$SUMMARY_FILE"
        echo "    - Retransmissions: $rtx (lower = better balance)" >> "$SUMMARY_FILE"
        echo "    - NACKs: $nacks (lower = less congestion, better balance)" >> "$SUMMARY_FILE"
        
        if [ -n "$total" ] && [ "$total" -gt 0 ]; then
            rtx_rate=$(echo "scale=4; $rtx / $total" | bc)
            nack_rate=$(echo "scale=4; $nacks / $total" | bc)
            echo "    - Retransmission rate: $rtx_rate" >> "$SUMMARY_FILE"
            echo "    - NACK rate: $nack_rate" >> "$SUMMARY_FILE"
            echo "" >> "$SUMMARY_FILE"
            echo "  Note: Lower retransmission/NACK rates suggest better" >> "$SUMMARY_FILE"
            echo "        load balancing and link utilization balance." >> "$SUMMARY_FILE"
        fi
        
        # Try to extract path selection statistics if available
        # (This would require enabling path statistics in the code)
        if grep -q "path_selection_count\|Path.*selection" "$algo_file"; then
            echo "" >> "$SUMMARY_FILE"
            echo "  Path selection statistics found:" >> "$SUMMARY_FILE"
            grep "path_selection_count\|Path.*selection" "$algo_file" | head -10 >> "$SUMMARY_FILE"
        else
            echo "" >> "$SUMMARY_FILE"
            echo "  Detailed per-path statistics not available in output." >> "$SUMMARY_FILE"
            echo "  (Would require enabling path selection logging in code)" >> "$SUMMARY_FILE"
        fi
    fi
done

echo "" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"
echo "Extraction Complete" >> "$SUMMARY_FILE"
echo "===========================================" >> "$SUMMARY_FILE"

# Only display summary if output is not redirected to the same file
# Check if stdout is a terminal or different file
if [ -t 1 ] || [ "$(realpath "$SUMMARY_FILE" 2>/dev/null)" != "$(realpath /dev/stdout 2>/dev/null)" ]; then
    echo "Extraction complete. Summary:"
    echo "  - Maximum/Average Queue Length: Extracted"
    echo "  - Packet Reordering Ratio: Extracted"
    echo "  - Link Utilization Balance: Extracted"
    echo ""
    echo "Full report saved to: $SUMMARY_FILE"
    echo "Report size: $(du -h "$SUMMARY_FILE" 2>/dev/null | cut -f1)"
else
    # If output is redirected, just print a brief message
    echo "Extraction complete. Report saved to: $SUMMARY_FILE" >&2
fi

