---
date: '2026-11-12T00:00:00-00:00'
title: 'Benchmarking cheap S3 on cheap VMs'
url: /blog/43
---

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.8/dist/chart.umd.min.js"></script>

# Contabo


## Backblaze B2 — East

{{< s3-benchmark-chart operation="upload" provider="b2-east" >}}
{{< s3-benchmark-chart operation="download" provider="b2-east" >}}

## Backblaze B2 — West

{{< s3-benchmark-chart operation="upload" provider="b2-west" >}}
{{< s3-benchmark-chart operation="download" provider="b2-west" >}}

## Cloudflare R2 — East

{{< s3-benchmark-chart operation="upload" provider="r2-east" >}}
{{< s3-benchmark-chart operation="download" provider="r2-east" >}}

## Cloudflare R2 — West

{{< s3-benchmark-chart operation="upload" provider="r2-west" >}}
{{< s3-benchmark-chart operation="download" provider="r2-west" >}}
