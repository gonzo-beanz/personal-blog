---
date: "2026-11-12T00:00:00-00:00"
title: "Benchmarking S3 alternatives on cheap VMs vs S3 on EC2"
url: /blog/43
---

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.min.css">
<script src="https://cdn.jsdelivr.net/npm/uplot@1.6.32/dist/uPlot.iife.min.js"></script>

I thought it would be fun to benchmark the performance of S3 providers on "cheap" VMs. It's a given that S3 to an EC2 machine performs fairly well as long as you're in the same region. But what happens when you're looking to save some money and avoid AWS altogether? How much performance are you giving up?

Let's find out!

# The S3 Providers

| Provider            | Storage<br/>$/TB/mo | Egress<br/>$/TB/mo | Notes                                                                |
| ------------------- | ------------------- | ------------------ | -------------------------------------------------------------------- |
| Backblaze B2        | $6.95               | $10                | Bandwidth is free up to 3x storage usage                             |
| Cloudflare R2       | $15                 | Free               | Fine details on the free egress, but most usage falls within it      |
| DigitalOcean Spaces | $20                 | $10                | Minimum price is $5.<br/>Includes 250GB of storage and 1TB of egress |
| Amazon S3           | $23                 | $90                | This is the king. Long live the king.                                |

All providers offer free ingress (data into S3). They have to lock you into the platform somehow.

First observation is that Backblaze stands out as a great deal compared to the rest both in storage and egress.

In general, the biggest difference in pricing from Amazon is egress (data out of S3). The egress pricing for Amazon is bananas. You have to commit to sending your data to Amazon because it costs so much to get the data out.

I considered these other providers but I had some issues:

| Provider               | Storage | Egress | Why I didn't test it                                                                        |
| ---------------------- | ------- | ------ | ------------------------------------------------------------------------------------------- |
| Contabo Object Storage | $11.96  | Free   | Max advertised throughput is only 10 megabytes / s                                          |
| Wasabi                 | $7.99   | Free   | Minimum of $7.99/mo. I used to have an account. I won't create a new one just for this test |
| Vultr Object Storage   | $20     | $10    | I was able to create a bucket in the panel but it wasn't accessible                         |

There's many other providers but I don't have infinite time. Reach out to me if you'd like to see a follow up with another provider.

# The benchmark details

For each of the VM hosts, I upload and then download files of different sizes:

- 100 kilobytes
- 1 mebabytes
- 10 megabytes
- 100 megabytes

For each upload/download operation I take 10 samples so I can measure the standard deviation.

For each operation I also attempt different levels of concurrency. For **uploads I do multipart uploads** of the files. For the smaller files we cannot test more than one level of concurrency since there's a minimum size for each part in a multipart upload.

For **downloads I do multiple HTTP range requests** for the file. For example, when downloading the 100 kilobyte file with a concurrency of 2 we would execute two simultaneous requests: one for the first 50 kilobytes and the other for the last 50 kilobytes.

Finally before each operation, I do a [HeadBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadBucket.html) request to measure the Round Trip Time (RTT). This is because some providers blocked ICMP pings to their endpoints 🤷.

# Hypotheses

I have a couple of hunches.

### 1. Cheaper S3 hosts will have less consistent throughput

Because of the way S3 is designed, it's more stable at large scales. There's a neat phenomenon where each tenant's different bursty usage patterns smooth out into the average (see [AWS re:Invent 2024 - Dive deep on Amazon S3 @ 13:16](https://youtu.be/NXehLy7IiPM?si=gTN5ZVIBASF12maf&t=796)).

This is similar to the electrical power grid. Your home electric tea kettle can use 1kw of power for 90s. An extremely bursty usage pattern that's imperceptible at scale. (There's obviously usage phenomenoms that contradict this, like World Cup matches)

I'm assuming that Amazon is by far the biggest provider even including GCP and Azure. They should have the most stable throughput given all the "extra" capacity they have at their scale.

### 2. Throughput is dependent on distance to the S3 service and size of the object

The closer you are to the service the more throughput. S3 works over HTTP which works over TCP. TCP has a simple formula for maximum throughput:

```
Window Size / Round Trip Time (RTT)
```

Where window size is smaller of the advertised receive window and sender congestion window (in bytes). Roundtrip time negatively affects the throughput. Linux hosts usually have a window size of 8 megabytes according to https://www.openpcap.com/tcp/tcp-window-scaling.

So if we compare 50 ms vs 500ms:

```
8 megabyte / .5 s  = 128 megabits / s
8 megabyte / .05 s = 1280 megabits / s
```

Another assumption is the bigger the file the more throughput. When a TCP connection is established the sender sends packets and gradually increases the number of packets until it reaches a threshold. This mechanism works by the sender detecting missing ACKs for packets. ACKs are affected by RTT. The ramp up time is therefore affected by RTT.

If the file is smaller and the S3 service is far away (high RTT) then the TCP connection might not have enough time to reach full-throughput.

### 3. Reading many small files is slower than reading one large file of the same total size

This hypothesis follows from the previous. If smaller files have a harder time reaching full throughput, we're better off using a larger file instead.

# The results per VM

This took quite a while to measure and compile. Please enjoy the colorful graphs.

## Contabo ($7.51 / mo)

First up is the cheapest and (unsurprisingly) worst performer!

This is a Cloud VPS 4 Core server. It features.

- 4 vCPU (shared)
- 8 GB RAM
- 100 GB SSD (?)
- 200 Mbps

The price displayed is after a 12 month commitment. It seemed like a bonkers deal and I slighty regret it because the disk performance is palpable. It adds quite a bit of wait to every operation. Go compilation no longer feels instant :(

The biggest limitation is the 200 Mbps. It's less than what I get at home!

### Backblaze B2

{{< s3-benchmark-rtt host="contabo" provider="b2-east" title="B2 East" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="210" >}}
</div>

{{< s3-benchmark-rtt host="contabo" provider="b2-west" title="B2 West" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="210" >}}
</div>

### Cloudflare R2

{{< s3-benchmark-rtt host="contabo" provider="r2-east" title="R2 East" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="210" >}}
</div>

{{< s3-benchmark-rtt host="contabo" provider="r2-west" title="R2 West" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="210" >}}
</div>

## DigitalOcean ($48 / mo)

Next up we have a Digital Ocean droplet from the NYC 1 region. It's got similar specs

- 4 vCPU (shared)
- 8 GB RAM
- 160 GB SSD
- 1 Gbps

Notably this one offer 1 Gbps. This machine feels way snappier is also more than 6x more expensive so it better be better.

### Backblaze B2

{{< s3-benchmark-rtt host="digital-ocean-nyc1" provider="b2-east" title="B2 East" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="3000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="3000" >}}
</div>

{{< s3-benchmark-rtt host="digital-ocean-nyc1" provider="b2-west" title="B2 West" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="1000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="1000" >}}
</div>

### Cloudflare R2

{{< s3-benchmark-rtt host="digital-ocean-nyc1" provider="r2-east" title="R2 East" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="2000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="2000" >}}
</div>

{{< s3-benchmark-rtt host="digital-ocean-nyc1" provider="r2-west" title="R2 West" >}}

<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="2000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc1" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="2000" >}}
</div>
