-- Round trip time from each host to each provider, in milliseconds.
-- RTT is measured per request and does not depend on object size or concurrency,
-- so the dimension grid only spans hosts and providers.
WITH
    hosts(host) AS (
        VALUES
            ('aws-us-east-1'),
            ('contabo'),
            ('digital-ocean-nyc3'),
            ('hetzner-ash-1')
    ),
    providers(provider) AS (
        VALUES
            ('aws-east-1'), ('aws-west-1'),
            ('b2-east'), ('b2-west'),
            ('do-east-nyc3'), ('do-west-sfo3'),
            ('r2-east'), ('r2-west')
    ),
    samples AS (
        SELECT
            json_extract(labels, '$.host') AS host,
            json_extract(labels, '$.provider') AS provider,
            CAST(value AS REAL) AS rtt_ms
        FROM metrics
        WHERE metric_name IN ('upload_rtt_ms', 'download_rtt_ms')
    )
SELECT
    hosts.host AS host,
    providers.provider AS provider,
    AVG(samples.rtt_ms) AS mean_rtt_ms,
    SQRT(
        (
            SUM(samples.rtt_ms * samples.rtt_ms)
            - (SUM(samples.rtt_ms) * SUM(samples.rtt_ms)) / COUNT(samples.rtt_ms)
        ) / (COUNT(samples.rtt_ms) - 1)
    ) AS std_dev_rtt_ms,
    COUNT(samples.rtt_ms) AS sample_count
FROM hosts
CROSS JOIN providers
LEFT JOIN samples
    ON samples.host = hosts.host
   AND samples.provider = providers.provider
GROUP BY hosts.host, providers.provider
ORDER BY hosts.host, providers.provider;
