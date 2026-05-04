use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReachabilityCaps {
    pub max_depth: u32,
    pub max_distance: f64,
    pub max_det_delta: Option<f64>,
    pub max_risk: Option<f64>,
    pub max_paths: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReachabilityPath {
    pub node_ids: Vec<i64>,
    pub edge_ids: Vec<i64>,
    pub depth: u32,
    pub distance: f64,
    pub log_cost: f64,
    pub path_prob: f64,
    pub det_sum: f64,
    pub cic_sum: f64,
    pub aos_sum: f64
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReachabilitySummary {
    pub snapshot_id: i64,
    pub tenant_id: String,
    pub origin_node_id: i64,
    pub hs_zone_selector: String,
    pub combined_reach_prob: f64,
    pub paths: Vec<ReachabilityPath>
}
