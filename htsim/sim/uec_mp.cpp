
#include "uec_mp.h"

#include <iostream>
#include <algorithm>  // for std::find
#include <vector>
#include <cmath>  // for sqrt


UecMpOblivious::UecMpOblivious(uint16_t no_of_paths,
                               bool debug)
    : UecMultipath(debug),
      _no_of_paths(no_of_paths),
      _current_ev_index(0)
      {

    _path_random = rand() % UINT16_MAX;  // random upper bits of EV
    _path_xor = rand() % _no_of_paths;

    if (_debug)
        cout << "Multipath"
            << " Oblivious"
            << " _no_of_paths " << _no_of_paths
            << " _path_random " << _path_random
            << " _path_xor " << _path_xor
            << endl;
}

void UecMpOblivious::processEv(uint16_t path_id, PathFeedback feedback) {
    return;
}

uint16_t UecMpOblivious::nextEntropy(uint64_t seq_sent, uint64_t cur_cwnd_in_pkts) {
    // _no_of_paths must be a power of 2
    uint16_t mask = _no_of_paths - 1;
    uint16_t entropy = (_current_ev_index ^ _path_xor) & mask;

    // set things for next time
    _current_ev_index++;
    if (_current_ev_index == _no_of_paths) {
        _current_ev_index = 0;
        _path_xor = rand() & mask;
    }

    entropy |= _path_random ^ (_path_random & mask);  // set upper bits
    return entropy;
}


UecMpBitmap::UecMpBitmap(uint16_t no_of_paths, bool debug)
    : UecMultipath(debug),
      _no_of_paths(no_of_paths),
      _current_ev_index(0),
      _ev_skip_bitmap(),
      _ev_skip_count(0)
      {

    _max_penalty = 15;

    _path_random = rand() % 0xffff;  // random upper bits of EV
    _path_xor = rand() % _no_of_paths;

    _ev_skip_bitmap.resize(_no_of_paths);
    for (uint32_t i = 0; i < _no_of_paths; i++) {
        _ev_skip_bitmap[i] = 0;
    }

    if (_debug)
        cout << "Multipath"
            << " Bitmap"
            << " _no_of_paths " << _no_of_paths
            << " _path_random " << _path_random
            << " _path_xor " << _path_xor
            << " _max_penalty " << (uint32_t)_max_penalty
            << endl;
}

void UecMpBitmap::processEv(uint16_t path_id, PathFeedback feedback) {
    // _no_of_paths must be a power of 2
    uint16_t mask = _no_of_paths - 1;
    path_id &= mask;  // only take the relevant bits for an index

    if (feedback != PathFeedback::PATH_GOOD && !_ev_skip_bitmap[path_id])
        _ev_skip_count++;

    uint8_t penalty = 0;

    if (feedback == PathFeedback::PATH_ECN)
        penalty = 1;
    else if (feedback == PathFeedback::PATH_NACK)
        penalty = 4;
    else if (feedback == PathFeedback::PATH_TIMEOUT)
        penalty = _max_penalty;

    _ev_skip_bitmap[path_id] += penalty;
    if (_ev_skip_bitmap[path_id] > _max_penalty) {
        _ev_skip_bitmap[path_id] = _max_penalty;
    }
}

uint16_t UecMpBitmap::nextEntropy(uint64_t seq_sent, uint64_t cur_cwnd_in_pkts) {
    // _no_of_paths must be a power of 2
    uint16_t mask = _no_of_paths - 1;
    uint16_t entropy = (_current_ev_index ^ _path_xor) & mask;
    bool flag = false;
    int counter = 0;
    while (_ev_skip_bitmap[entropy] > 0) {
        if (flag == false){
            _ev_skip_bitmap[entropy]--;
            if (!_ev_skip_bitmap[entropy]){
                assert(_ev_skip_count>0);
                _ev_skip_count--;
            }
        }

        flag = true;
        counter ++;
        if (counter > _no_of_paths){
            break;
        }
        _current_ev_index++;
        if (_current_ev_index == _no_of_paths) {
            _current_ev_index = 0;
            _path_xor = rand() & mask;
        }
        entropy = (_current_ev_index ^ _path_xor) & mask;
    }

    // set things for next time
    _current_ev_index++;
    if (_current_ev_index == _no_of_paths) {
        _current_ev_index = 0;
        _path_xor = rand() & mask;
    }

    entropy |= _path_random ^ (_path_random & mask);  // set upper bits
    return entropy;
}

UecMpReps::UecMpReps(uint16_t no_of_paths, bool debug, bool is_trimming_enabled)
    : UecMultipath(debug),
      _no_of_paths(no_of_paths),
      _crt_path(0),
      _is_trimming_enabled(is_trimming_enabled) {

    circular_buffer_reps = new CircularBufferREPS<uint16_t>(CircularBufferREPS<uint16_t>::repsBufferSize);

    if (_debug)
        cout << "Multipath"
            << " REPS"
            << " _no_of_paths " << _no_of_paths
            << endl;
}

void UecMpReps::processEv(uint16_t path_id, PathFeedback feedback) {

    if ((feedback == PATH_TIMEOUT) && !circular_buffer_reps->isFrozenMode() && circular_buffer_reps->explore_counter == 0) {
        if (_is_trimming_enabled) { // If we have trimming enabled
            circular_buffer_reps->setFrozenMode(true);
            circular_buffer_reps->can_exit_frozen_mode = EventList::getTheEventList().now() +  circular_buffer_reps->exit_freeze_after;
        } else {
            cout << timeAsUs(EventList::getTheEventList().now()) << "REPS currently requires trimming in this implementation." << endl;
            exit(EXIT_FAILURE); // If we reach this point, it means we are trying to enter freezing mode without trimming enabled.
        } // In this version of REPS, we do not enter freezing mode without trimming enabled. Check the REPS paper to implement it also without trimming.
    }

    if (circular_buffer_reps->isFrozenMode() && EventList::getTheEventList().now() > circular_buffer_reps->can_exit_frozen_mode) {
        circular_buffer_reps->setFrozenMode(false);
        circular_buffer_reps->resetBuffer();
        circular_buffer_reps->explore_counter = 16;
        // Clear MQL grouping when buffer is reset
        if (_use_mql) {
            _paths_by_mql_level.clear();
        }
    }

    if ((feedback == PATH_GOOD) && !circular_buffer_reps->isFrozenMode()) {
        circular_buffer_reps->add(path_id);
        // If MQL is enabled and we know MQL for this path, add to grouping
        if (_use_mql && _path_mql_map.count(path_id)) {
            addPathToGrouping(path_id, _path_mql_map[path_id]);
        }
    } else if (circular_buffer_reps->isFrozenMode() && (feedback == PATH_GOOD)) {
        circular_buffer_reps->add(path_id);
        // If MQL is enabled and we know MQL for this path, add to grouping
        if (_use_mql && _path_mql_map.count(path_id)) {
            addPathToGrouping(path_id, _path_mql_map[path_id]);
        }
    }
}

// Helper method to remove path from MQL grouping
void UecMpReps::removePathFromGrouping(uint16_t path_id) {
    for (auto& [level, paths] : _paths_by_mql_level) {
        auto it = std::find(paths.begin(), paths.end(), path_id);
        if (it != paths.end()) {
            paths.erase(it);
            if (paths.empty()) {
                _paths_by_mql_level.erase(level);
            }
            return;
        }
    }
}

// Helper method to add path to MQL grouping
void UecMpReps::addPathToGrouping(uint16_t path_id, uint8_t mql_level) {
    // Only add if path is actually in the buffer
    if (circular_buffer_reps->containsEntropy(path_id)) {
        // Remove from old grouping first
        removePathFromGrouping(path_id);
        // Add to new grouping
        _paths_by_mql_level[mql_level].push_back(path_id);
    }
}

// Helper method to update MQL grouping when MQL changes
void UecMpReps::updateMqlGrouping(uint16_t path_id, uint8_t old_mql, uint8_t new_mql) {
    // Only update if path is in buffer
    if (circular_buffer_reps->containsEntropy(path_id)) {
        removePathFromGrouping(path_id);
        addPathToGrouping(path_id, new_mql);
    }
}

// Process MQL feedback for SMaRTT-REPS-CONGA
void UecMpReps::processMql(uint16_t path_id, uint8_t mql_level) {
    // Get old MQL if exists
    uint8_t old_mql = _path_mql_map.count(path_id) ? _path_mql_map[path_id] : 7;
    
    // Update MQL for this path
    _path_mql_map[path_id] = mql_level;
    
    // Update MQL grouping if enabled
    if (_use_mql) {
        updateMqlGrouping(path_id, old_mql, mql_level);
    }
    
    // Update statistics
    _stats.mql_updates++;
    _stats.mql_level_distribution[mql_level]++;
    
    if (_debug) {
        cout << "REPS processMql: path_id=" << path_id 
             << " mql=" << (int)mql_level << endl;
    }
}

uint16_t UecMpReps::nextEntropy(uint64_t seq_sent, uint64_t cur_cwnd_in_pkts) {
    // Update statistics
    _stats.total_selections++;
    
    if (circular_buffer_reps->explore_counter > 0) {
        circular_buffer_reps->explore_counter--;
        uint16_t selected = rand() % _no_of_paths;
        _stats.path_selection_count[selected]++;
        return selected;
    }

    // MQL-based path selection for SMaRTT-REPS-CONGA
    // Strict priority: select randomly from the lowest available MQL level group
    if (_use_mql && !_paths_by_mql_level.empty()) {
        // Strict priority order: iterate from lowest MQL (0) to highest (7)
        for (uint8_t level = 0; level <= 7; level++) {
            if (_paths_by_mql_level.count(level) && !_paths_by_mql_level[level].empty()) {
                vector<uint16_t>& paths_at_level = _paths_by_mql_level[level];
                
                // Filter paths that are still in buffer (in case buffer was modified)
                vector<uint16_t> valid_paths;
                for (uint16_t path_id : paths_at_level) {
                    if (circular_buffer_reps->containsEntropy(path_id)) {
                        valid_paths.push_back(path_id);
                    }
                }
                
                if (!valid_paths.empty()) {
                    // Randomly choose one path from this MQL level group
                    uint16_t selected_path = valid_paths[rand() % valid_paths.size()];
                    
                    // Remove selected path from buffer (need to find and remove)
                    // Since CircularBufferREPS doesn't support direct removal by path_id,
                    // we use a workaround: remove all paths, then add back the unselected ones
                    vector<uint16_t> temp_paths;
                    
                    // Collect all paths from buffer
                    while (!circular_buffer_reps->isEmpty() && 
                           circular_buffer_reps->getNumberFreshEntropies() > 0) {
                        uint16_t path_id;
                        if (circular_buffer_reps->isFrozenMode()) {
                            path_id = circular_buffer_reps->remove_frozen();
                        } else {
                            path_id = circular_buffer_reps->remove_earliest_fresh();
                        }
                        if (path_id != selected_path) {
                            temp_paths.push_back(path_id);
                        }
                    }
                    
                    // Put unselected paths back to buffer
                    for (uint16_t path_id : temp_paths) {
                        circular_buffer_reps->add(path_id);
                    }
                    
                    // Remove selected path from MQL grouping
                    removePathFromGrouping(selected_path);
                    
                    // Update statistics
                    _stats.mql_based_selections++;
                    _stats.path_selection_count[selected_path]++;
                    
                    if (_debug) {
                        cout << "REPS MQL strict priority selection: path=" << selected_path 
                             << " mql=" << (int)level 
                             << " level_group_size=" << valid_paths.size() << endl;
                    }
                    
                    return selected_path;
                } else {
                    // Clean up invalid paths from this level
                    _paths_by_mql_level[level].clear();
                }
            }
        }
        
        // If we reach here, all paths in grouping are invalid, clear grouping
        _paths_by_mql_level.clear();
    }
    
    // Fall back to original REPS logic
    uint16_t selected;
    if (circular_buffer_reps->isFrozenMode()) {
        if (circular_buffer_reps->isEmpty()) {
            selected = rand() % _no_of_paths;
        } else {
            selected = circular_buffer_reps->remove_frozen();
        }
    } else {
        if (circular_buffer_reps->isEmpty() || circular_buffer_reps->getNumberFreshEntropies() == 0) {
            selected = _crt_path = rand() % _no_of_paths;
        } else {
            selected = circular_buffer_reps->remove_earliest_fresh();
        }
    }
    
    // Update statistics
    _stats.path_selection_count[selected]++;
    return selected;
}

// Print MQL statistics
void UecMpReps::printStats() const {
    if (!_use_mql) {
        cout << "MQL-based path selection is disabled" << endl;
        return;
    }
    
    cout << "\n========== REPS MQL Statistics ==========" << endl;
    cout << "Total path selections: " << _stats.total_selections << endl;
    if (_stats.total_selections > 0) {
        cout << "MQL-based selections: " << _stats.mql_based_selections 
             << " (" << (100.0 * _stats.mql_based_selections / _stats.total_selections) << "%)" << endl;
    }
    cout << "MQL updates received: " << _stats.mql_updates << endl;
    
    if (_stats.mql_updates > 0) {
        cout << "\nMQL Level Distribution:" << endl;
        for (uint8_t level = 0; level <= 7; level++) {
            auto it = _stats.mql_level_distribution.find(level);
            uint64_t count = (it != _stats.mql_level_distribution.end()) ? it->second : 0;
            if (count > 0) {
                cout << "  Level " << (int)level << ": " << count 
                     << " (" << (100.0 * count / _stats.mql_updates) << "%)" << endl;
            }
        }
    }
    
    if (!_stats.path_selection_count.empty()) {
        // Calculate utilization balance statistics
        vector<uint64_t> selection_counts;
        for (const auto& [path_id, count] : _stats.path_selection_count) {
            selection_counts.push_back(count);
        }
        
        // Calculate mean, variance, std_dev for utilization balance
        if (!selection_counts.empty()) {
            double mean = 0.0;
            for (uint64_t count : selection_counts) {
                mean += count;
            }
            mean /= selection_counts.size();
            
            double variance = 0.0;
            for (uint64_t count : selection_counts) {
                variance += (count - mean) * (count - mean);
            }
            variance /= selection_counts.size();
            double std_dev = sqrt(variance);
            double cv = (mean > 0) ? (std_dev / mean) : 0.0;  // Coefficient of Variation
            
            cout << "\nPath Selection Distribution (Utilization Balance):" << endl;
            cout << "  Total paths used: " << selection_counts.size() << endl;
            cout << "  Mean selections per path: " << mean << endl;
            cout << "  Std deviation: " << std_dev << endl;
            cout << "  Coefficient of Variation (CV): " << cv 
                 << " (lower = better balance)" << endl;
            
            // Find min and max
            uint64_t min_selections = *min_element(selection_counts.begin(), selection_counts.end());
            uint64_t max_selections = *max_element(selection_counts.begin(), selection_counts.end());
            cout << "  Min selections: " << min_selections << endl;
            cout << "  Max selections: " << max_selections << endl;
            if (mean > 0) {
                cout << "  Imbalance ratio (max/min): " << (double(max_selections) / min_selections) << endl;
            }
        }
        
        cout << "\nTop 10 Most Selected Paths:" << endl;
        vector<pair<uint16_t, uint64_t>> sorted_paths(_stats.path_selection_count.begin(), 
                                                        _stats.path_selection_count.end());
        sort(sorted_paths.begin(), sorted_paths.end(), 
             [](const auto& a, const auto& b) { return a.second > b.second; });
        
        for (size_t i = 0; i < min(size_t(10), sorted_paths.size()); i++) {
            cout << "  Path " << sorted_paths[i].first << ": " << sorted_paths[i].second 
                 << " (" << (100.0 * sorted_paths[i].second / _stats.total_selections) << "%)" << endl;
        }
        
        // Output all path selections for detailed analysis
        cout << "\nAll Path Selection Counts (for utilization balance analysis):" << endl;
        cout << "Path_ID:Selection_Count" << endl;
        for (const auto& [path_id, count] : _stats.path_selection_count) {
            cout << path_id << ":" << count << endl;
        }
    }
    cout << "=========================================" << endl;
}


UecMpRepsLegacy::UecMpRepsLegacy(uint16_t no_of_paths, bool debug)
    : UecMultipath(debug),
      _no_of_paths(no_of_paths),
      _crt_path(0) {

    if (_debug)
        cout << "Multipath"
            << " REPS"
            << " _no_of_paths " << _no_of_paths
            << endl;
}

void UecMpRepsLegacy::processEv(uint16_t path_id, PathFeedback feedback) {
    if (feedback == PATH_GOOD){
        _next_pathid.push_back(path_id);
        if (_debug){
            cout << timeAsUs(EventList::getTheEventList().now()) << " " << _debug_tag << " REPS Add " << path_id << " " << _next_pathid.size() << endl;
        }
    }
}

uint16_t UecMpRepsLegacy::nextEntropy(uint64_t seq_sent, uint64_t cur_cwnd_in_pkts) {
    if (seq_sent < min(cur_cwnd_in_pkts, (uint64_t)_no_of_paths)) {
        _crt_path++;
        if (_crt_path == _no_of_paths) {
            _crt_path = 0;
        }

        if (_debug) 
            cout << timeAsUs(EventList::getTheEventList().now()) << " " << _debug_tag << " REPS FirstWindow " << _crt_path << endl;

    } else {
        if (_next_pathid.empty()) {
            assert(_no_of_paths > 0);
		    _crt_path = random() % _no_of_paths;

            if (_debug) 
                cout << timeAsUs(EventList::getTheEventList().now()) << " " << _debug_tag << " REPS Steady " << _crt_path << endl;

        } else {
            _crt_path = _next_pathid.front();
            _next_pathid.pop_front();

            if (_debug) 
                cout << timeAsUs(EventList::getTheEventList().now()) << " " << _debug_tag << " REPS Recycle " << _crt_path << " " << _next_pathid.size() << endl;

        }
    }
    return _crt_path;
}

optional<uint16_t> UecMpRepsLegacy::nextEntropyRecycle() {
    if (_next_pathid.empty()) {
        return {};
    } else {
        _crt_path = _next_pathid.front();
        _next_pathid.pop_front();

        if (_debug) 
            cout << timeAsUs(EventList::getTheEventList().now()) << " " << _debug_tag << " MIXED Recycle " << _crt_path << " " << _next_pathid.size() << endl;
        return { _crt_path };
    }
}


UecMpMixed::UecMpMixed(uint16_t no_of_paths, bool debug)
    : UecMultipath(debug),
      _bitmap(UecMpBitmap(no_of_paths, debug)),
      _reps_legacy(UecMpRepsLegacy(no_of_paths, debug))
      {
}

void UecMpMixed::set_debug_tag(string debug_tag) {
    _bitmap.set_debug_tag(debug_tag);
    _reps_legacy.set_debug_tag(debug_tag);
}

void UecMpMixed::processEv(uint16_t path_id, PathFeedback feedback) {
    _bitmap.processEv(path_id, feedback);
    _reps_legacy.processEv(path_id, feedback);
}

uint16_t UecMpMixed::nextEntropy(uint64_t seq_sent, uint64_t cur_cwnd_in_pkts) {
    auto reps_val = _reps_legacy.nextEntropyRecycle();
    if (reps_val.has_value()) {
        return reps_val.value();
    } else {
        return _bitmap.nextEntropy(seq_sent, cur_cwnd_in_pkts);
    }
}

UecMpEcmp::UecMpEcmp(uint16_t no_of_paths, bool debug)
    : UecMultipath(debug),
      _crt_path(0) {
    if (_debug)
        cout << "Multipath"
            << " ECMP"
            << " _no_of_paths " << no_of_paths
            << endl;
    _crt_path = rand() % no_of_paths;
}

void UecMpEcmp::processEv(uint16_t path_id, PathFeedback feedback) {
    // No OP in ECMP
    return;
}

uint16_t UecMpEcmp::nextEntropy(uint64_t seq_sent, uint64_t cur_cwnd_in_pkts) {
    // Always same path for a given flow in ECMP
    return _crt_path;
}