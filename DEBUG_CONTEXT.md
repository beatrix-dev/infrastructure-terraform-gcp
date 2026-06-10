# GKE Terraform Configuration Issue - Context for Debugging

## Problem
Created a GKE cluster via Terraform that hung during creation, but the same cluster created successfully via GCP UI.

## Terraform Code That Failed (main.tf)
```hcl
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.0.0/20"
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

resource "google_container_cluster" "primary" {
  name       = var.cluster_name
  location   = var.region
  project    = var.project_id
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  deletion_protection = false
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "default"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
    disk_size_gb = 50
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
```

## GCP UI Export (Working Configuration)
Key differences in what GCP created:
- `initial_node_count = 0` (not 1)
- `remove_default_node_pool = null` (not true)
- Has a built-in `node_pool` block in cluster resource
- Secondary range name: "gke-cluster-1-pods-ed40b91c" (auto-generated, not "pods")
- `default_max_pods_per_node = 110`
- `enable_shielded_nodes = true`
- More comprehensive `addons_config`
- `datapath_provider = "LEGACY_DATAPATH"`
- `release_channel.channel = "REGULAR"`
- Various other explicit defaults

## Variables Used
```hcl
variable "project_id" {
  type    = string
  default = "terraform-498709"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "cluster_name" {
  type    = string
  default = "dev-cluster"
}
```

## Potential Issues to Investigate
1. **Initial node pool handling**: Using `remove_default_node_pool = true` with `initial_node_count = 1` might create conflicts
2. **Secondary range naming**: Custom names vs auto-generated names
3. **Node pool dependencies**: Maybe the node pool needs explicit `depends_on` the cluster
4. **Missing defaults**: GCP sets many defaults that Terraform might not handle correctly
5. **Resource ordering**: Cluster creation order vs node pool creation
6. **API version differences**: Terraform provider might handle resources differently than UI
7. **Secondary range configuration**: The way secondary ranges are defined in subnet vs referenced in cluster

## Questions for Investigation
- Why does GCP UI set `initial_node_count = 0` while Terraform requires `>= 1`?
- Why does removing `remove_default_node_pool` make it work?
- Are the secondary range names causing issues?
- Is there a timing issue with cluster/node pool creation?
