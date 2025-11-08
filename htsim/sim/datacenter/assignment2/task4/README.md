# Task 4: Congestion Scenario Experiment

## Experiment Design

This experiment creates a realistic datacenter congestion scenario to evaluate the performance of different load balancing algorithms (ECMP, OPS, REPS) under mixed traffic patterns.

### Topology

**3-Tier Fat Tree with 128 nodes and 4x oversubscription**
- File: `../../topologies/topo_assignment2/fat_tree_128_4os.topo`
- 8 pods, 16 hosts per pod
- 4 ToR switches per pod
- 4 Aggregation switches per pod  
- 16 Core switches
- 4x oversubscription at Aggregation tier

### Congestion Scenario

The communication matrix (`congestion_scenario.cm`) creates congestion through:

1. **Cross-pod flows** (6 flows)
   - Pod 0 → Pod 7 (different pods)
   - Creates congestion at core switches
   - Flow sizes: 50MB each

2. **Incast pattern** (7 flows)
   - Multiple senders from different pods → one receiver (node 64)
   - Creates congestion at receiver's ToR and Agg switches
   - Flow sizes: 30MB each
   - Staggered start time: 10ms

3. **Outcast pattern** (8 flows)
   - One sender (node 96) → multiple receivers in different pods
   - Creates congestion at sender's ToR and Agg switches
   - Flow sizes: 40MB each
   - Staggered start time: 20ms

4. **Additional cross-pod flows** (11 flows)
   - More cross-pod traffic with staggered start times
   - Flow sizes: 45-60MB
   - Start times: 5ms, 15ms

**Total: 32 concurrent flows** creating dynamic congestion patterns

### Performance Metrics

1. **Flow Completion Time (FCT)**
   - Mean, median, min, max FCT
   - P50, P95, P99 percentiles
   - Comparison across algorithms

2. **Queue Length Variance**
   - Average queue length per core switch
   - Variance across all core switches
   - Lower variance = better load balancing

## Running the Experiment

### Step 1: Run Simulations

```bash
cd task4
./run_congestion_experiment.sh
```

This will run simulations for ECMP, OPS (Oblivious), and REPS algorithms. Results are saved in `results/` directory.

### Step 2: Extract FCT Data

```bash
./extract_fct.sh
```

This extracts Flow Completion Time statistics for all algorithms.

### Step 3: Extract Queue Variance Data

```bash
./extract_queue_variance.sh
```

This extracts queue length variance for core switches.

### Step 4: Comprehensive Analysis

```bash
python3 analyze_results.py
```

This provides a comprehensive comparison of all algorithms on both metrics.

## Expected Insights

1. **ECMP**: 
   - Static hash-based routing
   - May create uneven load distribution
   - Higher queue variance expected

2. **OPS (Oblivious)**:
   - Random path selection
   - Better load distribution than ECMP
   - But no congestion awareness

3. **REPS**:
   - Adaptive path selection based on feedback
   - Should show best load balancing (lowest variance)
   - Should adapt to congestion patterns

## Files

- `congestion_scenario.cm`: Communication matrix defining the congestion scenario
- `run_congestion_experiment.sh`: Main experiment script
- `extract_fct.sh`: Extract FCT metrics
- `extract_queue_variance.sh`: Extract queue variance metrics
- `analyze_results.py`: Comprehensive analysis script
- `results/`: Directory containing all simulation outputs


