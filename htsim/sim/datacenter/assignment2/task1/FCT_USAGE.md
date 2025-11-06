# Flow Completion Time (FCT) Calculation Guide

## Overview

The `extract_fct_from_log.py` script calculates Flow Completion Time (FCT) from simulation output files. FCT is the time taken for a flow to complete, measured from start to finish.

## Usage

### Basic Usage

```bash
python3 extract_fct_from_log.py <output_file> [connection_matrix_file]
```

### Examples

```bash
# Calculate FCT for ECMP experiment
python3 extract_fct_from_log.py results/dctcp_ecmp.out ../../connection_matrices/cm_assignment2/one.cm

# Calculate FCT for REPS experiment
python3 extract_fct_from_log.py results/dctcp_reps.out ../../connection_matrices/cm_assignment2/one.cm

# Calculate FCT for OBLIVIOUS experiment
python3 extract_fct_from_log.py results/dctcp_oblivious.out ../../connection_matrices/cm_assignment2/one.cm
```

### Automatic FCT Calculation

The `run_lb_experiments.sh` script automatically calculates FCT after each experiment run and saves it to:
- `results/dctcp_ecmp_fct.txt`
- `results/dctcp_reps_fct.txt`
- `results/dctcp_oblivious_fct.txt`

## Output Format

The script outputs:
- **FCT**: Flow Completion Time in microseconds (us) and milliseconds (ms)
- **Size**: Flow size in bytes and MB
- **Throughput**: Achieved throughput in Gbps
- **Packets**: Estimated packet count
- **Start/End Time**: Flow start and end timestamps
- **Statistics**: Mean, Median, Min, Max, P50, P95, P99

### Example Output

```
============================================================
Flow Completion Time (FCT) Analysis
============================================================

Found 1 flow completion(s):

Flow 1: flow_0_16
  FCT: 11655.60 us (11.66 ms)
  Size: 20,000,000 bytes (19.07 MB)
  Throughput: 13.73 Gbps
  Packets: 4819
  Start: 63.50 us
  End: 11719.10 us

============================================================
FCT Statistics:
============================================================
  Count:    1
  Mean:     11655.60 us (11.66 ms)
  Median:   11655.60 us (11.66 ms)
  Min:      11655.60 us (11.66 ms)
  Max:      11655.60 us (11.66 ms)
  P50:      11655.60 us (11.66 ms)
  P95:      11655.60 us (11.66 ms)
  P99:      11655.60 us (11.66 ms)
============================================================
```

## How It Works

1. **Connection Matrix Parsing**: Reads flow information (source, destination, size, start time) from the connection matrix file
2. **DCTCP Event Extraction**: Searches for DCTCP events in the output file to find flow start and end times
3. **FCT Calculation**: Calculates FCT as the difference between last DCTCP event time and flow start time
4. **Statistics**: Computes various statistics (mean, median, percentiles) if multiple flows exist

## Integration with Analysis Script

The `analyze_results.sh` script automatically includes FCT information in the summary report if FCT files exist.

## Troubleshooting

### No FCT Found

If the script reports "No flow completion times found":
1. Check that the output file contains DCTCP events (look for lines with "DCTCP start")
2. Verify the connection matrix file path is correct
3. Ensure the flow names in the connection matrix match the format expected (e.g., `0->16`)

### Incorrect FCT Values

If FCT values seem incorrect:
1. Check that the connection matrix file matches the experiment configuration
2. Verify that the flow size in the connection matrix is correct
3. Ensure the simulation completed successfully (check for "Done" in output)

## Notes

- FCT is calculated based on DCTCP event timestamps in the output file
- If multiple flows exist, the script will calculate FCT for each flow
- The script automatically searches for connection matrix files in common locations if not specified

