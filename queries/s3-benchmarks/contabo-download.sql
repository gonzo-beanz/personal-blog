-- Download throughput moments for the Contabo host, in decimal megabits per second.
-- Keep the complete dimension grid so missing measurements appear as null in charts.
WITH
    providers(provider) AS (
        VALUES ('b2-east'), ('b2-west'), ('r2-east'), ('r2-west')
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
            json_extract(labels, '$.provider') AS provider,
            CAST(json_extract(labels, '$.parallel_con') AS INTEGER) AS concurrency,
            CAST(
                REPLACE(REPLACE(json_extract(labels, '$.size'), ' byte', ''), '_', '')
                AS INTEGER
            ) AS size_bytes,
            CAST(value AS REAL) * 8.0 / 1000000.0 AS throughput_mbps
        FROM metrics
        WHERE metric_name = 'download_throughput_bytes_s'
          AND json_extract(labels, '$.host') = 'contabo'
    )
SELECT
    providers.provider AS provider,
    concurrencies.concurrency AS concurrency,
    sizes.size_bytes AS size_bytes,
    sizes.size_label AS size_label,
    AVG(samples.throughput_mbps) AS avg_mbps,
    SUM(samples.throughput_mbps) AS sum_mbps,
    SUM(samples.throughput_mbps * samples.throughput_mbps) AS sum_squares_mbps,
    COUNT(samples.throughput_mbps) AS sample_count
FROM providers
CROSS JOIN concurrencies
CROSS JOIN sizes
LEFT JOIN samples
    ON samples.provider = providers.provider
   AND samples.concurrency = concurrencies.concurrency
   AND samples.size_bytes = sizes.size_bytes
GROUP BY providers.provider, concurrencies.concurrency, sizes.size_bytes, sizes.size_label
ORDER BY providers.provider, concurrencies.concurrency, sizes.size_bytes;
