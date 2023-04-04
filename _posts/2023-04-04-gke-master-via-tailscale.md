---
layout: post
title: Securely connect to your GKE control plane (master) using Tailscale
categories: [Tailscale, GCP, GKE]
---

# TLDR
To securely connect to you GKE control plane using private IPs only: 1) set up a Compute Engine VM, install Tailscale and advertise the route to the GKE control plane, and 2) make sure the client is in the same tailnet and fetch the cluster credentials with the `--internal-ip` flag.

# Introduction
When accessing private/internal resources, you usually want two layers of security: authentication (handled by GCP IAM) and connectivity (handled by networking configuration). In case of a vulnerability your resource will still be protected by the other layer.

To apply this concept to GKE, it is good practice to disable the public/external IP to connect to the control plane (master) API, and connect via some bastion host to the control plane. For years, I have set up such a bastion host in GCP, and people would need to set up and SSH tunnel to the bastion and reconfigure their local Kubernetes configuration a bit to proxy the traffic via the bastion host.

This worked, but we can do this way simpler with one of my favourite pieces of software: [Tailscale](https://tailscale.com). I love Tailscale for its ease-of-use, security and speed. I use it for many purposes; just one of them is to connect to GKE.

# Solution
Because the GKE control plane is managed by Google, we can't install Tailscale on it, so we need a dedicated VM for this. The solution will look like this:

![Access GKE control plane using Tailscale](/images/gke-via-tailscale.svg)

Of course, you will want to set this up using Terraform!

Let's go through the components:

## GKE
Create a GKE cluster with just a private IP. You can leave the master authorized networks list empty if the Tailscale node is deployed in the same subnet. Else, you would need to add the private IP of the Tailscale node.

When the cluster is created, find the private IP of the control plane. In this example, we'll use `172.16.0.32`.

## Tailscale node
Because it's not possible to install Tailscale on the GKE control plane itself we need to deploy a Compute Engine VM for it. If you use Cloud NAT, you can deploy the VM even without a public IP. Now, connect to the VM (you can copy this SSH command from the GCP console):

```bash
gcloud compute ssh tailscale \
  --zone my-zone \
  --tunnel-through-iap \
  --project my-project
```

[Install Tailscale](https://tailscale.com/kb/1031/install-linux/) on the node (ideally you would create the VM with Terraform and install Tailscale using a startup script or pre-baked image).

Because this node acts as a proxy to the control plane, we need to advertise the routes when starting Tailscale. Make sure you also accept these advertised routes in your Tailscale admin console:

`tailscale up --advertise-routes=172.16.0.32/32`

Accept the advertised route for the node in the [Tailscale admin console](https://login.tailscale.com/admin/machines). From now on, any client in your tailnet that makes a request to the GKE control plane's private IP, will be routed through the Tailscale node in GCP.

## Client
The client (Kubernetes administrator) needs to be logged in to an existing tailnet. No magic needed here.

Next, fetch the cluster credentials:

```bash
gcloud container clusters get-credentials my-cluster \
  --region my-region \
  --internal-ip \
  --project my-project
```

That's all; you don't need to configure any `proxy-url` in your `kubeconfig` and/or accept invalid certificates, it just works now. You can confirm by running:

`kubectl get nodes`
