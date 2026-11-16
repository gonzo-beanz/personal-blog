-- Throughput moments for every host and operation, in decimal megabits per second.
-- Keep the complete dimension grid so missing measurements appear as null in charts.
WITH
    hosts(host) AS (
        VALUES
            ('aws-us-east-1'),
            ('contabo'),
            ('digital-ocean-nyc3'),
            ('hetzner-ash-1')
    ),
    metric_names(metric_name) AS (
        VALUES ('upload_throughput_bytes_s'), ('download_throughput_bytes_s')
    ),
    providers(provider) AS (
        VALUES
            ('aws-east-1'), ('aws-west-1'),
            ('b2-east'), ('b2-west'),
            ('do-east-nyc3'), ('do-west-sfo3'),
            ('r2-east'), ('r2-west')
    ),
    concurrencies(concurrency) AS (
        VALUES (1), (2), (4)
    ),
    sizes(size_bytes, size_label) AS (
        VALUES
            (100000, '100 KB'),
            (1000000, '1 MB'),
            (10000000, '10 MB'),
            (100000000, '100 MB')
    ),
    samples AS (
        SELECT
            json_extract(labels, '$.host') AS host,
            metric_name,
            json_extract(labels, '$.provider') AS provider,
            CAST(json_extract(labels, '$.parallel_con') AS INTEGER) AS concurrency,
            CAST(
                REPLACE(REPLACE(json_extract(labels, '$.size'), ' byte', ''), '_', '')
                AS INTEGER
            ) AS size_bytes,
            CAST(value AS REAL) * 8.0 / 1000000.0 AS throughput_mbps
        FROM metrics
    )
SELECT
    hosts.host AS host,
    metric_names.metric_name AS metric_name,
    providers.provider AS provider,
    concurrencies.concurrency AS concurrency,
    sizes.size_bytes AS size_bytes,
    sizes.size_label AS size_label,
    AVG(samples.throughput_mbps) AS avg_mbps,
    SUM(samples.throughput_mbps) AS sum_mbps,
    SUM(samples.throughput_mbps * samples.throughput_mbps) AS sum_squares_mbps,
    COUNT(samples.throughput_mbps) AS sample_count
FROM hosts
CROSS JOIN metric_names
CROSS JOIN providers
CROSS JOIN concurrencies
CROSS JOIN sizes
LEFT JOIN samples
    ON samples.host = hosts.host
   AND samples.metric_name = metric_names.metric_name
   AND samples.provider = providers.provider
   AND samples.concurrency = concurrencies.concurrency
   AND samples.size_bytes = sizes.size_bytes
GROUP BY
    hosts.host,
    metric_names.metric_name,
    providers.provider,
    concurrencies.concurrency,
    sizes.size_bytes,
    sizes.size_label
ORDER BY
    hosts.host,
    metric_names.metric_name,
    providers.provider,
    concurrencies.concurrency,
    sizes.size_bytes;
