---
date: '2026-11-12T00:00:00-00:00'
title: 'Benchmarking cheap S3 on cheap VMs'
url: /blog/43
---

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.min.css">
<script src="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.iife.min.js"></script>

# Contabo


## Backblaze B2 — East

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart operation="upload" provider="b2-east" >}}
{{< s3-benchmark-chart operation="download" provider="b2-east" >}}
</div>

## Backblaze B2 — West

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart operation="upload" provider="b2-west" >}}
{{< s3-benchmark-chart operation="download" provider="b2-west" >}}
</div>

## Cloudflare R2 — East

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart operation="upload" provider="r2-east" >}}
{{< s3-benchmark-chart operation="download" provider="r2-east" >}}
</div>

## Cloudflare R2 — West

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart operation="upload" provider="r2-west" >}}
{{< s3-benchmark-chart operation="download" provider="r2-west" >}}
</div>
