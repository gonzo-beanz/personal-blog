---
date: '2026-11-12T00:00:00-00:00'
title: 'Benchmarking cheap S3 on cheap VMs'
url: /blog/43
---

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.min.css">
<script src="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.iife.min.js"></script>

# Contabo


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
