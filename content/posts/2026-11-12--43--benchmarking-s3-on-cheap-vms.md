---
date: "2026-11-12T00:00:00-00:00"
title: "Benchmarking S3 alternatives: How do cheap VMs compare to S3 on EC2"
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

All providers offer free ingress (data into S3). This is how they lock you into the platform!

First observation is that Backblaze stands out as a great deal both in terms of storage and egress.

In general, the biggest difference in pricing from Amazon is egress (data out of S3). The egress pricing for Amazon is bananas. You have to commit to sending your data to Amazon because it costs so much to get the data out.

I considered these other providers but I had some issues:

| Provider               | Storage | Egress | Why I didn't test it                                                                        |
| ---------------------- | ------- | ------ | ------------------------------------------------------------------------------------------- |
| Contabo Object Storage | $11.96  | Free   | Max advertised throughput is only 10 megabytes / s                                          |
| Wasabi                 | $7.99   | Free   | Minimum of $7.99/mo. I used to have an account. I won't create a new one just for this test |
| Vultr Object Storage   | $20     | $10    | I was able to create a bucket in the panel but it wasn't accessible via the API             |

There's many other providers but I don't have infinite time. Reach out to me if you'd like to see a follow up with another provider.

# The benchmark details

I setup two buckets in each of the S3 providers: one in the US east region and one in the US west region.

I then spun up one VM host for each hosting provider in the US east region. This allows us to test if a higher RTT affects throughput.

For each of the VM hosts, I upload and then download files of different sizes:
- 100 kilobytes
- 1 mebabytes
- 10 megabytes
- 100 megabytes

For each upload/download operation I take 10 samples so I can measure the standard deviation.

For each operation I also attempt different levels of concurrency. For **uploads I do multipart uploads** of the files. For the smaller files we cannot test more than one level of concurrency since there's a minimum size for each part in a multipart upload.

For **downloads I do multiple HTTP range requests** for the file. For example, when downloading the 100 kilobyte file with a concurrency of 2 we would execute two simultaneous requests: one for the first 50 kilobytes and the other for the last 50 kilobytes.

I stand up each VM host as close as possible to AWS's `us-east-1`. I'm assuming that the other providers are geographically close.

![US East Coast Data Center Map pointing to AWS us-east-1 rough location](/img/posts/43/us-east-coast-data-center-map.png)

Finally before each operation, I do a [HeadBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadBucket.html) request to measure the Round Trip Time (RTT). Why this instead of just a plain old ICMP ping? Because some providers blocked the poings 🤷.

# Hypotheses

I have a couple of hunches.

### 1. Cheaper S3 hosts will have less consistent throughput

Because of the way S3 is designed, it's more stable at larger scales. There's a neat phenomenon where each tenant's different bursty usage patterns smooth out into the average (see [AWS re:Invent 2024 - Dive deep on Amazon S3 @ 13:16](https://youtu.be/NXehLy7IiPM?si=gTN5ZVIBASF12maf&t=796)).

I'm assuming that Amazon is by far the biggest provider even including GCP and Azure. Amazon should have the most stable throughput given all the "extra" capacity they have at their scale.

### 2. Throughput is dependent on distance to the S3 provider

The closer you are to the service the more throughput. S3 works over HTTP which works over TCP. 

TCP has a simple formula for maximum throughput:

```
Window Size / Round Trip Time (RTT)
```

Where window size is smaller of the advertised receive window and sender congestion window (in bytes). **Roundtrip time negatively affects the throughput**. Linux hosts usually have a window size of 8 megabytes according to https://www.openpcap.com/tcp/tcp-window-scaling.

So if we compare 50 ms vs 500ms:

```
8 megabyte / .5 s  = 128 megabits / s
8 megabyte / .05 s = 1280 megabits / s
```

### 3. Throughput is dependent on the size of the object

Another assumption is that the bigger the file the higher the throughput. 

When a TCP connection is established the sender sends packets and gradually increases the number of packets until it reaches a threshold. This mechanism works by the sender detecting missing ACKs for packets. ACKs are affected by RTT. The ramp up time is therefore affected by RTT.

If the file is smaller and the S3 service is far away (high RTT) then the TCP connection might not have enough time to reach full-throughput.

# Summary

For context, here is the latency table for each host and each S3 provider. Each value is the **mean RTT** from the host to the S3 bucket.

As an example, I've marked first column, third row in red below.

This cell says: "From **AWS EC2** it takes **4.5 ms** to get a response from **B2 East**"

{{< s3-benchmark-rtt-table >}}

The only one that's strange is R2 East. It's almost the same RTT as the west region!

## East <--> East

The results were NOT what I had expected.

{{< s3-benchmark-summary region="east" title="100 MB download (4 concurrency) — East regions" concurrency="4" max_y="8000" >}}

First of all, the Contabo host has it's bandwidth capped at 200 Mbits / s. Poor chap.

My first impression is that my first hypotheses was correct. S3 is way more consistent than the other providers. Look at that tiny standard deviation! 

My second assumption also seems correct. **R2 East** has the worst latency of the east buckets and has the worst throughput. The digital ocean facilty seems to be the closest (mean RTT of 48.2 ms) and this one ends up being the fastest with R2 East!

Lastly, I never would have bet that Backblaze and DigitalOcean can beat S3 in throughput IN THEIR OWN DATACENTERS. As far as I know, they both have their own data centers and don't colocate within Amazon. Maybe they do? They at least must have dedicated fiber connections to AWS to achieve this performance. So interesting. 

This makes these S3 alternatives way more appealing. Specially DigitalOcean! They have really consistent performance.

## East <--> West

Measuring throughput to the West regions gives a way more level playing field.

{{< s3-benchmark-summary region="west" title="100 MB download (4 concurrency) — West regions" concurrency="4" max_y="8000" >}}

Here interstingly enough Cloudflare performs really well. It performed horribly in the East<<->>East benchmark so they have a weird specialization in cross-region throughput?

# The results per VM

Generally, I tried to keep all the VM instance sizing the same (2 vCPU and 4 GB RAM, attached drives). Except for the Contabo VPS which has way more CPU and RAM than it should at that price.

This took quite a while to measure and compile. Please enjoy the colorful graphs.

## AWS ($55.84 / mo + $1.60 / mo storage)

The AWS EC2 machine I chose is **c6a.large**. It features

- 2 vCPU
- 4 GB RAM
- 20 GB Elastic Block Storage (EBS)
- "Up to 5 Gbps"

I chose this one over the similar t3a.medium instance since the `t` instances have bursty CPUs and I was worried the burstiness might affect the benchmark timings. Also it seems like a fairer comparison to other VMs, even if those other VMs offer "shared" vCPUs instead of dedicated vCPUs. This is yet another variable that's hard to control since it's unclear how much of vCPU you are provisioned in ANY cloud/provider.

{{< s3-benchmark-tabs >}}
<div data-title="AWS East">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="aws-east-1" title="AWS East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="aws-east-1" metric="upload_throughput_bytes_s" title="AWS East - Upload" max_y="3500" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="aws-east-1" metric="download_throughput_bytes_s" title="AWS East - Download" max_y="3500" >}}
</div>
</div>
<div data-title="AWS West">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="aws-west-1" title="AWS West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="aws-west-1" metric="upload_throughput_bytes_s" title="AWS West - Upload" max_y="1500" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="aws-west-1" metric="download_throughput_bytes_s" title="AWS West - Download" max_y="1500" >}}
</div>
</div>
<div data-title="B2 East">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="b2-east" title="B2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="5000" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="5000" >}}
</div>
</div>
<div data-title="B2 West">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="b2-west" title="B2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="800" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="800" >}}
</div>
</div>
<div data-title="DO Spaces East">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="do-east-nyc3" title="DO Spaces East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="do-east-nyc3" metric="upload_throughput_bytes_s" title="DO Spaces East - Upload" max_y="6500" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="do-east-nyc3" metric="download_throughput_bytes_s" title="DO Spaces East - Download" max_y="6500" >}}
</div>
</div>
<div data-title="DO Spaces West">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="do-west-sfo3" title="DO Spaces West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="do-west-sfo3" metric="upload_throughput_bytes_s" title="DO Spaces West - Upload" max_y="2000" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="do-west-sfo3" metric="download_throughput_bytes_s" title="DO Spaces West - Download" max_y="2000" >}}
</div>
</div>
<div data-title="R2 East">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="r2-east" title="R2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="1800" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="1800" >}}
</div>
</div>
<div data-title="R2 West">
{{< s3-benchmark-rtt host="aws-us-east-1" provider="r2-west" title="R2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="aws-us-east-1" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="1800" >}}{{< s3-benchmark-chart host="aws-us-east-1" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="1800" >}}
</div>
</div>
{{< /s3-benchmark-tabs >}}

## Contabo ($7.51 / mo)

The cheapest and (unsurprisingly) worst performer! The price displayed is after a 12 month commitment.

This is a **Cloud VPS 4 Core** server. It features

- 4 vCPU (shared)
- 8 GB RAM
- 100 GB SSD (?)
- 200 Mbps

It seemed like a bonkers deal and I slighty regret it because the disk is not an NVMe and may not even be an SSD. The drive performance is palpable. It adds quite a bit of wait to every operation. Go compilation no longer feels instant :(

The biggest limitation is the 200 Mbps. It's less than what I get at home!

{{< s3-benchmark-tabs >}}
<div data-title="AWS East">
{{< s3-benchmark-rtt host="contabo" provider="aws-east-1" title="AWS East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="aws-east-1" metric="upload_throughput_bytes_s" title="AWS East - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="aws-east-1" metric="download_throughput_bytes_s" title="AWS East - Download" max_y="210" >}}
</div>
</div>
<div data-title="AWS West">
{{< s3-benchmark-rtt host="contabo" provider="aws-west-1" title="AWS West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="aws-west-1" metric="upload_throughput_bytes_s" title="AWS West - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="aws-west-1" metric="download_throughput_bytes_s" title="AWS West - Download" max_y="210" >}}
</div>
</div>
<div data-title="B2 East">
{{< s3-benchmark-rtt host="contabo" provider="b2-east" title="B2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="210" >}}
</div>
</div>
<div data-title="B2 West">
{{< s3-benchmark-rtt host="contabo" provider="b2-west" title="B2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="210" >}}
</div>
</div>
<div data-title="DO Spaces East">
{{< s3-benchmark-rtt host="contabo" provider="do-east-nyc3" title="DO Spaces East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="do-east-nyc3" metric="upload_throughput_bytes_s" title="DO Spaces East - Upload" max_y="320" >}}
{{< s3-benchmark-chart host="contabo" provider="do-east-nyc3" metric="download_throughput_bytes_s" title="DO Spaces East - Download" max_y="320" >}}
</div>
</div>
<div data-title="DO Spaces West">
{{< s3-benchmark-rtt host="contabo" provider="do-west-sfo3" title="DO Spaces West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="do-west-sfo3" metric="upload_throughput_bytes_s" title="DO Spaces West - Upload" max_y="220" >}}
{{< s3-benchmark-chart host="contabo" provider="do-west-sfo3" metric="download_throughput_bytes_s" title="DO Spaces West - Download" max_y="220" >}}
</div>
</div>
<div data-title="R2 East">
{{< s3-benchmark-rtt host="contabo" provider="r2-east" title="R2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="210" >}}
</div>
</div>
<div data-title="R2 West">
{{< s3-benchmark-rtt host="contabo" provider="r2-west" title="R2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="contabo" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="210" >}}
{{< s3-benchmark-chart host="contabo" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="210" >}}
</div>
</div>
{{< /s3-benchmark-tabs >}}

## DigitalOcean ($24 / mo)

The Digital Ocean Droplet used the NYC3 region to give it the best home field advantage with the NYC3 Spaces storage. It has...

- 2 vCPU (shared)
- 4 GB RAM
- 80 GB SSD
- 1 Gbps

Notably this one offer 1 Gbps. This machine feels way snappier than the Contabo VPS.

{{< s3-benchmark-tabs >}}
<div data-title="AWS East">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="aws-east-1" title="AWS East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="aws-east-1" metric="upload_throughput_bytes_s" title="AWS East - Upload" max_y="2200" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="aws-east-1" metric="download_throughput_bytes_s" title="AWS East - Download" max_y="2200" >}}
</div>
</div>
<div data-title="AWS West">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="aws-west-1" title="AWS West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="aws-west-1" metric="upload_throughput_bytes_s" title="AWS West - Upload" max_y="900" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="aws-west-1" metric="download_throughput_bytes_s" title="AWS West - Download" max_y="900" >}}
</div>
</div>
<div data-title="B2 East">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="b2-east" title="B2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="3000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="3000" >}}
</div>
</div>
<div data-title="B2 West">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="b2-west" title="B2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="1000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="1000" >}}
</div>
</div>
<div data-title="DO Spaces East">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="do-east-nyc3" title="DO Spaces East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="do-east-nyc3" metric="upload_throughput_bytes_s" title="DO Spaces East - Upload" max_y="3200" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="do-east-nyc3" metric="download_throughput_bytes_s" title="DO Spaces East - Download" max_y="3200" >}}
</div>
</div>
<div data-title="DO Spaces West">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="do-west-sfo3" title="DO Spaces West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="do-west-sfo3" metric="upload_throughput_bytes_s" title="DO Spaces West - Upload" max_y="1500" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="do-west-sfo3" metric="download_throughput_bytes_s" title="DO Spaces West - Download" max_y="1500" >}}
</div>
</div>
<div data-title="R2 East">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="r2-east" title="R2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="2000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="2000" >}}
</div>
</div>
<div data-title="R2 West">
{{< s3-benchmark-rtt host="digital-ocean-nyc3" provider="r2-west" title="R2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="2000" >}}
{{< s3-benchmark-chart host="digital-ocean-nyc3" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="2000" >}}
</div>
</div>
{{< /s3-benchmark-tabs >}}

## Hetzner (€17.49 | ~$19.28 / mo)

The Hetzner VM used the ash-1 region. I thought this would be really close to the AWS S3 east region and it was! Mean RTT was 5.7 ms! The specs:

- 2 vCPU (shared)
- 4 GB RAM
- 80 GB SSD
- 1 Gbps

This feels a little snappier than the Digital Ocean Droplet. I've used Hetzner for a long time up until they hit me with 2 price increases in 6 months. Up until that moment, I was very satisfied with the CPU and disk performance.

{{< s3-benchmark-tabs >}}
<div data-title="AWS East">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="aws-east-1" title="AWS East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="aws-east-1" metric="upload_throughput_bytes_s" title="AWS East - Upload" max_y="3500" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="aws-east-1" metric="download_throughput_bytes_s" title="AWS East - Download" max_y="3500" >}}
</div>
</div>
<div data-title="AWS West">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="aws-west-1" title="AWS West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="aws-west-1" metric="upload_throughput_bytes_s" title="AWS West - Upload" max_y="1500" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="aws-west-1" metric="download_throughput_bytes_s" title="AWS West - Download" max_y="1500" >}}
</div>
</div>
<div data-title="B2 East">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="b2-east" title="B2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="b2-east" metric="upload_throughput_bytes_s" title="B2 East - Upload" max_y="5000" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="b2-east" metric="download_throughput_bytes_s" title="B2 East - Download" max_y="5000" >}}
</div>
</div>
<div data-title="B2 West">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="b2-west" title="B2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="b2-west" metric="upload_throughput_bytes_s" title="B2 West - Upload" max_y="800" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="b2-west" metric="download_throughput_bytes_s" title="B2 West - Download" max_y="800" >}}
</div>
</div>
<div data-title="DO Spaces East">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="do-east-nyc3" title="DO Spaces East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="do-east-nyc3" metric="upload_throughput_bytes_s" title="DO Spaces East - Upload" max_y="6500" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="do-east-nyc3" metric="download_throughput_bytes_s" title="DO Spaces East - Download" max_y="6500" >}}
</div>
</div>
<div data-title="DO Spaces West">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="do-west-sfo3" title="DO Spaces West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="do-west-sfo3" metric="upload_throughput_bytes_s" title="DO Spaces West - Upload" max_y="2000" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="do-west-sfo3" metric="download_throughput_bytes_s" title="DO Spaces West - Download" max_y="2000" >}}
</div>
</div>
<div data-title="R2 East">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="r2-east" title="R2 East" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="r2-east" metric="upload_throughput_bytes_s" title="R2 East - Upload" max_y="1800" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="r2-east" metric="download_throughput_bytes_s" title="R2 East - Download" max_y="1800" >}}
</div>
</div>
<div data-title="R2 West">
{{< s3-benchmark-rtt host="hetzner-ash-1" provider="r2-west" title="R2 West" >}}
<div class="s3-benchmark-chart-row">
{{< s3-benchmark-chart host="hetzner-ash-1" provider="r2-west" metric="upload_throughput_bytes_s" title="R2 West - Upload" max_y="1800" >}}{{< s3-benchmark-chart host="hetzner-ash-1" provider="r2-west" metric="download_throughput_bytes_s" title="R2 West - Download" max_y="1800" >}}
</div>
</div>
{{< /s3-benchmark-tabs >}}


## Closing thoughts

You can [download the benchmark database](/downloads/s3-benchmark-reporting.db.gz) in case you're curious. Some quick info about it:

```bash
$ gunzip reporting_clean.db.gz


$ sqlite3 reporting_clean.db


reporting_clean.db-> .schema
CREATE TABLE metrics (
        metric_name TEXT NOT NULL,
        labels TEXT NOT NULL CHECK (json_valid(labels) AND json_type(labels) = 'object'),
        value
);


reporting_clean.db-> SELECT 
  COUNT(*), json_extract(labels, '$.host') as host 
FROM metrics 
GROUP BY host;
╭──────────┬────────────────────╮
│ COUNT(*) │        host        │
╞══════════╪════════════════════╡
│     5520 │ aws-us-east-1      │
│     5522 │ contabo            │
│     5522 │ digital-ocean-nyc3 │
│     5522 │ hetzner-ash-1      │
╰──────────┴────────────────────╯


reporting_clean.db-> SELECT 
  DISTINCT metric_name 
FROM metrics 
ORDER BY metric_name;
╭─────────────────────────────╮
│         metric_name         │
╞═════════════════════════════╡
│ download_attempts_count     │
│ download_rtt_ms             │
│ download_throughput_bytes_s │
│ download_ttfb_ms            │
│ upload_attempts_count       │
│ upload_failures_count       │
│ upload_rtt_ms               │
│ upload_throughput_bytes_s   │
╰─────────────────────────────╯
```

When I started this benchmarking pursuit, I didn't expect to get these wacky results. I swear everytime I profile performance I'm surprised in one way or another.

This took a lot of time to organize, compile the data, and more importantly demonstrate in a digestible format. I'm out of words haha. 

I'm happy to discuss this in [hackernews](https://news.ycombinator.com/item?id=50546325), [bluesky](https://bsky.app/profile/gonzobea.nz/post/3n2lpp4jrqc2d), [reddit](https://www.reddit.com/r/programming/comments/1xzfsjo/benchmarking_s3_alternatives_how_do_cheap_vms/), [oldreddit](https://old.reddit.com/r/programming/comments/1xzfsjo/benchmarking_s3_alternatives_how_do_cheap_vms/?ref=share&ref_source=link).
