SELECT
    client_id,
    content_id,
    total_clicks_60d,
    total_impressions_60d,
    ROUND(avg_position_60d, 2) AS avg_position_60d,
    ROUND(avg_ctr_60d, 4) AS avg_ctr_60d,
    ROUND(pos_volatility_60d, 2) AS pos_volatility_60d,
    ROUND(click_velocity_pct, 4) AS click_velocity_pct,
    ROUND(impression_velocity_pct, 4) AS impression_velocity_pct,
    ROUND(position_drift_delta, 2) AS position_drift_delta,
    clicks_future_30d,
    ROUND(future_click_change_pct, 4) AS future_click_change_pct,
    is_decaying_target
FROM (
    SELECT
        f.client_id,
        f.content_id,
        f.total_clicks_60d,
        f.total_impressions_60d,
        f.avg_position_60d,
        f.avg_ctr_60d,
        f.pos_volatility_60d,
        (f.clicks_recent_30d - f.clicks_base_30d) / NULLIF(f.clicks_base_30d, 0) AS click_velocity_pct,
        (f.impressions_recent_30d - f.impressions_base_30d) / NULLIF(f.impressions_base_30d, 0) AS impression_velocity_pct,
        (f.pos_recent_30d - f.pos_base_30d) AS position_drift_delta,
        COALESCE(t.clicks_future_30d, 0) AS clicks_future_30d,
        (COALESCE(t.clicks_future_30d, 0) - f.clicks_recent_30d) / NULLIF(f.clicks_recent_30d, 0) AS future_click_change_pct,
        CASE
            WHEN (COALESCE(t.clicks_future_30d, 0) - f.clicks_recent_30d) / NULLIF(f.clicks_recent_30d, 0) <= -0.25 THEN 1
            ELSE 0
        END AS is_decaying_target
    FROM (
        SELECT
            client_id,
            content_id,
            SUM(clicks) AS total_clicks_60d,
            SUM(impressions) AS total_impressions_60d,
            AVG(position) AS avg_position_60d,
            AVG(ctr) AS avg_ctr_60d,
            SUM(CASE WHEN report_date < '2026-03-31' THEN clicks ELSE 0 END) AS clicks_base_30d,
            SUM(CASE WHEN report_date < '2026-03-31' THEN impressions ELSE 0 END) AS impressions_base_30d,
            AVG(CASE WHEN report_date < '2026-03-31' THEN position END) AS pos_base_30d,
            SUM(CASE WHEN report_date BETWEEN '2026-03-31' AND '2026-04-30' THEN clicks ELSE 0 END) AS clicks_recent_30d,
            SUM(CASE WHEN report_date BETWEEN '2026-03-31' AND '2026-04-30' THEN impressions ELSE 0 END) AS impressions_recent_30d,
            AVG(CASE WHEN report_date BETWEEN '2026-03-31' AND '2026-04-30' THEN position END) AS pos_recent_30d,
            STDDEV(position) AS pos_volatility_60d
        FROM fact_content_daily_performance
        WHERE report_date >= '2026-03-01'
          AND report_date < '2026-05-01'
        GROUP BY client_id, content_id
        HAVING SUM(impressions) >= 100 AND SUM(clicks) >= 5
    ) AS f
    LEFT JOIN (
        SELECT
            client_id,
            content_id,
            SUM(clicks) AS clicks_future_30d,
            SUM(impressions) AS impressions_future_30d,
            AVG(position) AS pos_future_30d
        FROM fact_content_daily_performance
        WHERE report_date >= '2026-05-01'
          AND report_date < '2026-06-01'
        GROUP BY client_id, content_id
    ) AS t
        ON f.client_id = t.client_id
       AND f.content_id = t.content_id
) AS engineered_dataset
ORDER BY total_clicks_60d DESC;