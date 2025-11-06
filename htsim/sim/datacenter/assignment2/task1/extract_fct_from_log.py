#!/usr/bin/env python3
"""
Extract Flow Completion Time (FCT) from logout.dat log files and output files
"""

import sys
import os
import re
import struct
from statistics import mean, median

def parse_binary_log(log_file):
    """Parse binary log file logout.dat"""
    flow_completions = []
    
    if not os.path.exists(log_file):
        return flow_completions
    
    try:
        with open(log_file, 'rb') as f:
            # Read header information
            line = f.readline()
            while line:
                line_str = line.decode('utf-8', errors='ignore').strip()
                if line_str.startswith('#') or not line_str:
                    line = f.readline()
                    continue
                if 'numrecords' in line_str:
                    # Parse record count
                    match = re.search(r'numrecords=(\d+)', line_str)
                    if match:
                        num_records = int(match.group(1))
                        # Read records (simplified version, actual format may be more complex)
                        # This needs to be parsed according to the actual binary format
                        break
                line = f.readline()
    except Exception as e:
        print(f"Warning: Could not parse binary log: {e}")
    
    return flow_completions

def calculate_fct_from_stats(output_file, connection_matrix_file):
    """Calculate FCT from statistics and connection matrix"""
    fcts = []
    flow_info = []
    
    # Read connection matrix to get all flow information
    flows_from_cm = []
    if os.path.exists(connection_matrix_file):
        with open(connection_matrix_file, 'r') as f:
            for line in f:
                if '->' in line:
                    parts = line.split()
                    src = None
                    dst = None
                    flow_size = 0
                    start_time_us = 0
                    
                    # First extract source and destination (handle "0->8" format)
                    for part in parts:
                        if '->' in part:
                            # Directly handle "0->8" format
                            src_dst_parts = part.split('->')
                            if len(src_dst_parts) == 2:
                                try:
                                    src = int(src_dst_parts[0])
                                    dst = int(src_dst_parts[1])
                                except:
                                    pass
                            break
                    
                    # Then extract size and start
                    for i, part in enumerate(parts):
                        if part == 'size' and i + 1 < len(parts):
                            flow_size = int(parts[i+1])
                        elif part == 'start' and i + 1 < len(parts):
                            start_time_us = float(parts[i+1])
                    
                    if src is not None and dst is not None:
                        flows_from_cm.append({
                            'src': src,
                            'dst': dst,
                            'size': flow_size,
                            'start_time': start_time_us,
                            'name': f'flow_{src}_{dst}',
                            'uec_name': f'Uec_{src}_{dst}'
                        })
    
    # If no flows read from connection matrix, create a default one
    if not flows_from_cm:
        flows_from_cm.append({
            'src': 0,
            'dst': 16,
            'size': 2000000000,
            'start_time': 0,
            'name': 'flow_0_16',
            'uec_name': 'Uec_0_16'
        })
    
    # Extract time information for each flow from output file
    with open(output_file, 'r') as f:
        lines = f.readlines()
    
    # Find corresponding DCTCP events for each flow
    for flow in flows_from_cm:
        uec_name = flow['uec_name']
        first_dctcp_time = None
        last_dctcp_time = None
        
        for line in lines:
            # Find DCTCP events for this flow
            match = re.search(r'^(\d+\.\d+)\s+DCTCP.*' + re.escape(uec_name), line)
            if match:
                current_time = float(match.group(1))
                if first_dctcp_time is None:
                    first_dctcp_time = current_time
                last_dctcp_time = current_time
        
        # Use start time from connection matrix, or first DCTCP time as start
        start_time_us = flow['start_time']
        if start_time_us == 0 and first_dctcp_time is not None:
            start_time_us = first_dctcp_time
        
        # Calculate FCT
        if last_dctcp_time is not None and start_time_us is not None:
            fct_us = last_dctcp_time - start_time_us
            if fct_us > 0:
                fcts.append(fct_us)
                flow_info.append({
                    'name': flow['name'],
                    'fct_us': fct_us,
                    'size_bytes': flow['size'],
                    'start_time': start_time_us,
                    'end_time': last_dctcp_time,
                    'packets': flow['size'] // 4150 if flow['size'] > 0 else 0,  # Estimate packet count
                    'throughput_gbps': (flow['size'] * 8) / (fct_us * 1e-6) / 1e9 if fct_us > 0 else 0
                })
    
    return fcts, flow_info

def extract_fct_from_output(output_file):
    """Extract FCT directly from output file (if exists)"""
    fcts = []
    flow_info = []
    
    with open(output_file, 'r') as f:
        for line in f:
            # Find flow completion information
            if "Flow" in line and ("finished" in line or "complete" in line):
                patterns = [
                    r'Flow\s+(\S+)\s+finished\s+at\s+(\d+\.?\d*)\s+total\s+bytes\s+(\d+)',
                    r'Flow\s+(\S+).*finished.*at\s+(\d+\.?\d*)',
                ]
                
                for pattern in patterns:
                    match = re.search(pattern, line, re.IGNORECASE)
                    if match:
                        flow_name = match.group(1) if len(match.groups()) > 1 else "unknown"
                        fct_us = float(match.group(2) if len(match.groups()) > 1 else match.group(1))
                        flow_size = int(match.group(3)) if len(match.groups()) > 2 else 0
                        
                        fcts.append(fct_us)
                        flow_info.append({
                            'name': flow_name,
                            'fct_us': fct_us,
                            'size_bytes': flow_size,
                            'throughput_gbps': (flow_size * 8) / (fct_us * 1e-6) / 1e9 if flow_size > 0 and fct_us > 0 else 0
                        })
                        break
    
    return fcts, flow_info

def calculate_statistics(fcts):
    """Calculate FCT statistics"""
    if not fcts:
        return None
    
    sorted_fcts = sorted(fcts)
    n = len(sorted_fcts)
    
    return {
        'count': n,
        'mean': mean(fcts),
        'median': median(fcts),
        'min': min(fcts),
        'max': max(fcts),
        'p50': sorted_fcts[n//2] if n > 0 else 0,
        'p95': sorted_fcts[int(n * 0.95)] if n > 1 else sorted_fcts[-1],
        'p99': sorted_fcts[int(n * 0.99)] if n > 1 else sorted_fcts[-1],
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python extract_fct_from_log.py <output_file> [connection_matrix_file]")
        print("  or: python extract_fct_from_log.py <output_file> <log_file>")
        sys.exit(1)
    
    output_file = sys.argv[1]
    connection_matrix_file = sys.argv[2] if len(sys.argv) > 2 else None
    log_file = "logout.dat"  # Default log file
    
    # First try to extract directly from output file
    fcts, flow_info = extract_fct_from_output(output_file)
    
    # If not found, try to calculate from statistics
    if not fcts:
        if connection_matrix_file and os.path.exists(connection_matrix_file):
            fcts, flow_info = calculate_fct_from_stats(output_file, connection_matrix_file)
        else:
            # Try to find connection matrix in current directory
            possible_cm_files = [
                "../../connection_matrices/cm_assignment2/one.cm",
                "../../connection_matrices/assignment2/one.cm",
                "../connection_matrices/cm_assignment2/one.cm",
                "connection_matrices/cm_assignment2/one.cm",
            ]
            for cm_file in possible_cm_files:
                if os.path.exists(cm_file):
                    fcts, flow_info = calculate_fct_from_stats(output_file, cm_file)
                    break
    
    # If still not found, try to parse log file
    if not fcts and os.path.exists(log_file):
        log_fcts = parse_binary_log(log_file)
        if log_fcts:
            fcts = log_fcts
            # If no flow_info, create default
            if not flow_info:
                flow_info = [{'name': f'flow_{i}', 'fct_us': fct} for i, fct in enumerate(fcts)]
    
    if fcts:
        stats = calculate_statistics(fcts)
        
        print(f"\n{'='*60}")
        print(f"Flow Completion Time (FCT) Analysis")
        print(f"{'='*60}")
        print(f"\nFound {len(fcts)} flow completion(s):\n")
        
        for i, info in enumerate(flow_info, 1):
            print(f"Flow {i}: {info.get('name', 'unknown')}")
            print(f"  FCT: {info['fct_us']:.2f} us ({info['fct_us']/1000:.2f} ms)")
            if info.get('size_bytes', 0) > 0:
                print(f"  Size: {info['size_bytes']:,} bytes ({info['size_bytes']/1024/1024:.2f} MB)")
                print(f"  Throughput: {info['throughput_gbps']:.2f} Gbps")
            if 'packets' in info:
                print(f"  Packets: {info['packets']}")
            if 'start_time' in info:
                print(f"  Start: {info['start_time']:.2f} us")
                print(f"  End: {info['end_time']:.2f} us")
            print()
        
        print(f"\n{'='*60}")
        print(f"FCT Statistics:")
        print(f"{'='*60}")
        print(f"  Count:    {stats['count']}")
        print(f"  Mean:     {stats['mean']:.2f} us ({stats['mean']/1000:.2f} ms)")
        print(f"  Median:   {stats['median']:.2f} us ({stats['median']/1000:.2f} ms)")
        print(f"  Min:      {stats['min']:.2f} us ({stats['min']/1000:.2f} ms)")
        print(f"  Max:      {stats['max']:.2f} us ({stats['max']/1000:.2f} ms)")
        print(f"  P50:      {stats['p50']:.2f} us ({stats['p50']/1000:.2f} ms)")
        print(f"  P95:      {stats['p95']:.2f} us ({stats['p95']/1000:.2f} ms)")
        print(f"  P99:      {stats['p99']:.2f} us ({stats['p99']/1000:.2f} ms)")
        print(f"{'='*60}\n")
    else:
        print("No flow completion times found.")
        print("\nTried:")
        print("  1. Direct extraction from output file")
        if connection_matrix_file:
            print(f"  2. Calculation from stats (using {connection_matrix_file})")
        print("  3. Binary log parsing (logout.dat)")
        print("\nTip: Flow events may be in logout.dat (binary format)")
        sys.exit(1)

