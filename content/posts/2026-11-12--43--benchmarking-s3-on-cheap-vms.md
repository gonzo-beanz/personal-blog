---
date: "2026-11-12T00:00:00-00:00"
title: "Benchmarking S3 alternatives on cheap VMs"
url: /blog/43
---

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.min.css">
<script src="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.iife.min.js"></script>

# The S3 Providers

| Provider               | Storage          | Egress Pricing | Notes                                                         |
| ---------------------- | ---------------- | -------------- | ------------------------------------------------------------- |
| Backblaze B2           | $6.95 / TB / mo  | $10 / TB       | Bandwidth is free up to 3x storage usage                      |
| Contabo Object Storage | $11.96 / TB / mo | Free           | Min price is $2.99. Includes 250GB. Charged in 250 GB blocks  |
| Cloudflare R2          | $15 / TB / mo    | Free           | Fine details on the free egress, but most use falls within it |
| DigitalOcean Spaces    | $20 / TB / mo    | Free           | Fine details on the free egress, but most use falls within it |
| Vultr Object Storage   | $20 / TB / mo    | $10 / TB       | Minimum price is $18/mo. Includes 1TB of storage and egress   |
| Amazon S3              | $23 / TB / mo    | $90 / TB       | This is the king. Pricing here for reference                  |

Most providers are not free

# Contabo ($7.51 / mo)

First up is the cheapest and (unsurprisingly) worst performer!

This is a Cloud VPS 4 Core server. It features.

- 4 vCPU (shared)
- 8 GB RAM
- 100 GB SSD (?)
- 200 Mbps

The price displayed is after a 12 month commitment. It seemed like a bonkers deal and I slighty regret it because the disk performance is palpable. It adds quite a bit of wait to every operation. Go compilation no longer feels instant :(

The biggest limitation is the 200 Mbps. It's less than what I get at home!

## Backblaze B2

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="210" >}}
</div>

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="210" >}}
</div>

## Cloudflare R2

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="210" >}}
</div>

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="210" >}}
</div>

# DigitalOcean ($48 / mo)

Next up we have a Digital Ocean droplet from the NYC 1 region. It's got similar specs

- 4 vCPU (shared)
- 8 GB RAM
- 160 GB SSD
- 1 Gbps

Notably this one offer 1 Gbps. This machine feels way snappier is also more than 6x more expensive so it better be better.

## Backblaze B2

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="3000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="3000" >}}
</div>

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="1000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="1000" >}}
</div>

## Cloudflare R2

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="2000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="2000" >}}
</div>

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="2000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="2000" >}}
</div>
