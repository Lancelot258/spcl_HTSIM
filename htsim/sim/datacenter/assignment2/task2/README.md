# Task 3: Core Switch Queue Usage Logging

## Overview

This task runs simulation with `one.cm` connection matrix and logs queue usage for core switches in Fat-tree topology.

## Files

- **`run_switch_queue_logging.sh`**: Script to run simulation with queue usage logging
- **`extract_core_queue_usage.sh`**: Script to extract core switch queue usage from binary log
- **`parse_switch_queue.sh`**: Legacy script for parsing switch queue data (for reference)
- **`extract_spine_queue_summary.sh`**: Legacy script for Spine switches (for reference)

## Configuration

The simulation parameters match those from `run_lb_experiments.sh`:
- **Nodes**: 128
- **Topology**: Fat-tree 128 nodes (4x oversubscribed)
- **Connection Matrix**: `three.cm` (3 connections)
- **Congestion Control**: DCTCP
- **Load Balancing**: REPS
- **Queue Type**: composite_ecn
- **Queue Size**: 100 packets
- **ECN Thresholds**: 20% (low), 80% (high)
- **Paths**: 200
- **Initial CWND**: 1 packet
- **MTU**: 1500 bytes
- **End Time**: 1000 microseconds
- **Log Type**: `queue_usage` (logs QUEUE_APPROX events)
- **Log Time**: 10 microseconds (sampling period)

## Connection Matrix

`one.cm` contains 1 connections:
- `0->8`: Starts at time 0, size 200MB


## Topology

Uses `fat_tree_128_4os.topo` (Fat-tree 3-tier topology):
- **Tier 0 (ToR)**: ToR switches
- **Tier 1 (Aggregation)**: Aggregation switches
- **Tier 2 (Core)**: Core switches (these are logged)

## Usage

### Step 1: Run Simulation

```bash
bash run_switch_queue_logging.sh
```

This will:
- Run the simulation with queue usage logging enabled
- Generate `results/simulation.out` (standard output)
- Generate `logout.dat` (binary log with queue usage data)
- Generate `idmap.txt` (ID mapping file)

### Step 2: Extract Core Switch Queue Usage

```bash
bash extract_core_queue_usage.sh
```

This will:
- Parse the binary log file (`logout.dat`)
- Extract QUEUE_APPROX events for core switches (Switch_Core_*)
- Generate `results/core_queue_usage.txt` (raw queue usage data)
- Generate `results/core_queue_usage_summary.txt` (statistics summary)

## Output Files

### Simulation Output
- `results/simulation.out`: Standard simulation output
- `logout.dat`: Binary log file with queue usage data
- `idmap.txt`: ID mapping file showing switch IDs and names

### Extracted Data
- `results/core_queue_usage.txt`: Raw queue usage data for all core switches
- `results/core_queue_usage_summary.txt`: Summary statistics for each core switch

## Queue Usage Data Format

The queue usage data uses `QUEUE_APPROX` events with the following format:

```
Time Type QUEUE_APPROX ID X Ev RANGE LastQ Y MinQ Z MaxQ W Name Switch_Core_N
```

### Fields

- **Time**: Simulation time in seconds
- **Type**: `QUEUE_APPROX` (queue approximation event)
- **ID**: Switch ID (numeric)
- **Ev**: `RANGE` (queue range event)
- **LastQ**: Current queue size in bytes (at sampling time)
- **MinQ**: Minimum queue size in bytes (during sampling period)
- **MaxQ**: Maximum queue size in bytes (during sampling period)
- **Name**: Switch name (e.g., `Switch_Core_0`)

### Example

```
0.000010000 Type QUEUE_APPROX ID 100 Ev RANGE LastQ 4150 MinQ 0 MaxQ 8300 Name Switch_Core_0
```

This means:
- At time 0.00001 seconds (10 microseconds)
- Switch_Core_0 (ID: 100) has:
  - Current queue size: 4150 bytes (1 packet)
  - Minimum during period: 0 bytes
  - Maximum during period: 8300 bytes (2 packets)

## Switch Identification

In Fat-tree topology:
- Core switches are named `Switch_Core_0`, `Switch_Core_1`, etc.
- Switch IDs can be found in `idmap.txt`
- The extraction script automatically identifies all core switches

## Notes

- Queue usage logging uses `-log queue_usage` which generates `QUEUE_APPROX` events
- Sampling period is 10 microseconds (`-logtime_us 10`)
- Queue sizes are in bytes
- The script filters for core switches only (Switch_Core_*)

## Troubleshooting

If extraction fails:
1. Ensure simulation completed successfully (check `results/simulation.out`)
2. Verify `logout.dat` exists and is not empty
3. Check that `idmap.txt` exists
4. Ensure `parse_output` executable is available (script will attempt to compile if needed)
