# Parameters Setting
EXECUTABLE="../../../build/datacenter/htsim_uec"
TOPOLOGY="../../topologies/topo_assignment2/fat_tree_128_4os.topo"
CONNECTION_MATRIX="../../connection_matrices/cm_assignment2/one.cm"



algo="ecmp"

# Run experiment
$EXECUTABLE \
    -nodes 128 \
    -topo "$TOPOLOGY" \
    -tm "$CONNECTION_MATRIX" \
    -sender_cc_algo dctcp \
    -load_balancing_algo "$algo" \
    -queue_type composite_ecn \
    -q 100 \
    -ecn 20 80 \
    -paths 200 \
    -cwnd 100 \
    -mtu 1500 \
    -end 1000 \
    -log flow_events \
    -seed 0

