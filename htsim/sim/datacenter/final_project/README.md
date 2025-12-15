# Experiment Summary

This directory contains all essential experiment files, results, and analysis.

## Directory Structure

```
experiment_summary/
├── experiment_results/     # Latest experiment results (results_final_fixed_*)
├── logs/                   # Experiment execution logs
├── analysis/               # Analysis scripts and outputs
├── test_scripts/           # Test execution scripts
├── connection_matrices/    # Traffic scenario definitions
└── README.md              # This file
```

## Key Files

### Experiment Results
- `experiment_results/results_final_fixed_*/` - Complete experiment outputs
  - `comprehensive_analysis.txt` - Detailed comparison analysis
  - `results_summary.csv` - CSV format summary
  - `*/three_metrics_extracted.txt` - Per-scenario metrics

### Analysis
- `extract_three_metrics.sh` - Script to extract three key metrics
- `analyze_final_results.sh` - Comprehensive analysis script
- Various analysis output files

### Test Scripts
- `test_strict_priority_comprehensive.sh` - Comprehensive test script
- `run_final_experiments_fixed.sh` - Final experiments with fixed code

### Connection Matrices
- `three_way_test_scenario.cm` - Mixed Traffic scenario
- `severe_incast_scenario.cm` - Severe Incast scenario
- `all_to_all_scenario.cm` - All-to-All scenario

## Three Key Metrics Collected

1. **Queue Length** - NACKs (queue overflow indicator)
2. **Packet Reordering Ratio** - NACK rate (NACKs/Total Packets)
3. **Link Utilization Balance** - CV (Coefficient of Variation), Imbalance ratio

## Experiment Scenarios

1. **Mixed Traffic** - 118 flows with diverse patterns
2. **Severe Incast** - 64 sources → 1 destination, 320MB
3. **All-to-All** - 32 nodes × 31 destinations = 992 flows

## Algorithms Tested

1. **ECMP** - Static hash-based routing
2. **REPS (ECN)** - ECN-based dynamic recycling
3. **REPS-CONGA (MQL)** - 3-bit MQL with strict priority

