pub fn compute_reachability_prob(
    conn: &rusqlite::Connection,
    snapshot_id: i64,
    tenant_id: &str,
    origin_node_id: i64,
    hs_zone_selector: &str,
    caps: &ReachabilityCaps
) -> rusqlite::Result<ReachabilitySummary>;
