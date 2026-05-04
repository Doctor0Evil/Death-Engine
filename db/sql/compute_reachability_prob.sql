-- db/sql/compute_reachability_prob.sql
--
-- Core recursive CTE for probabilistic reachability on the blast graph.
-- This query expects:
--   :source_node_id   -- INTEGER
--   :max_depth        -- INTEGER
--   :max_distance     -- REAL (optional, can be NULL)
--   :max_paths        -- INTEGER (used when post-processing results)
--
-- Tables:
--   constellation_neighbor_edge      -- deterministic edges
--   hpc_probabilistic_edge          -- per-edge successProb, isIntermittent, etc.
--   constellation_filenode          -- used to filter high-sensitivity targets

WITH RECURSIVE
paths AS (
    -- Seed with outgoing edges from the source node.
    SELECT
        e.source_filenode_id AS start_id,
        e.target_filenode_id AS current_id,
        e.distance           AS distance,
        -LOG(pe.success_prob) AS log_cost,
        printf('%d', e.edge_id) AS edge_ids,
        1 AS depth
    FROM constellation_neighbor_edge AS e
    JOIN hpc_probabilistic_edge AS pe
      ON pe.edge_key = e.edge_id
     AND pe.snapshot_id = :snapshot_id
     AND pe.tenant_id = :tenant_id
    WHERE e.source_filenode_id = :source_node_id
      AND e.enabled = 1
      AND pe.success_prob > 0.0

    UNION ALL

    -- Expand to next-hop neighbors, respecting depth and optional distance limits.
    SELECT
        p.start_id,
        e.target_filenode_id AS current_id,
        p.distance + e.distance AS distance,
        p.log_cost + (-LOG(pe.success_prob)) AS log_cost,
        p.edge_ids || ',' || e.edge_id AS edge_ids,
        p.depth + 1 AS depth
    FROM paths AS p
    JOIN constellation_neighbor_edge AS e
      ON e.source_filenode_id = p.current_id
     AND e.enabled = 1
    JOIN hpc_probabilistic_edge AS pe
      ON pe.edge_key = e.edge_id
     AND pe.snapshot_id = :snapshot_id
     AND pe.tenant_id = :tenant_id
    WHERE p.depth < :max_depth
      AND pe.success_prob > 0.0
      AND (
            :max_distance IS NULL
         OR p.distance + e.distance <= :max_distance
      )
),
target_paths AS (
    -- Restrict to targets of interest (e.g., high-sensitivity zones).
    SELECT
        p.current_id AS target_node_id,
        p.depth,
        p.distance,
        p.log_cost,
        p.edge_ids
    FROM paths AS p
    JOIN constellation_filenode AS fn
      ON fn.filenode_id = p.current_id
    WHERE fn.object_kind = 'highSensitivityZone'
),
ranked_paths AS (
    -- Rank paths per target by ascending log_cost (i.e., highest success probability first).
    SELECT
        tp.*,
        ROW_NUMBER() OVER (
            PARTITION BY tp.target_node_id
            ORDER BY tp.log_cost ASC
        ) AS rank_per_target
    FROM target_paths AS tp
)
SELECT
    target_node_id,
    depth,
    distance,
    log_cost,
    edge_ids
FROM ranked_paths
WHERE rank_per_target <= :max_paths;
