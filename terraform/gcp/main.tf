terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Cloud Storage Bucket for Analytics Data
resource "google_storage_bucket" "analytics_data" {
  name          = "${var.project_id}-analytics-data"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Cloud Storage Bucket for Flink Jobs
resource "google_storage_bucket" "flink_jobs" {
  name          = "${var.project_id}-flink-jobs"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "dataproc-network"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "dataproc-subnet"
  ip_cidr_range = "10.1.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Firewall Rule
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "icmp"
  }
  
  source_ranges = ["10.1.0.0/16"]
}

# Dataproc Cluster for Flink
resource "google_dataproc_cluster" "analytics_cluster" {
  name   = "analytics-cluster"
  region = var.region
  
  cluster_config {
    staging_bucket = google_storage_bucket.flink_jobs.name
    
    master_config {
      num_instances = 1
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }
    
    worker_config {
      num_instances = 2
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 50
      }
    }
    
    software_config {
      image_version = "2.1-debian11"
      optional_components = ["FLINK"]
    }
    
    gce_cluster_config {
      network    = google_compute_network.vpc.name
      subnetwork = google_compute_subnetwork.subnet.name
      
      internal_ip_only = false
      
      tags = ["dataproc", "analytics"]
    }
  }
}

# Outputs
output "analytics_bucket_name" {
  value = google_storage_bucket.analytics_data.name
}

output "flink_jobs_bucket_name" {
  value = google_storage_bucket.flink_jobs.name
}

output "dataproc_cluster_name" {
  value = google_dataproc_cluster.analytics_cluster.name
}

output "dataproc_cluster_region" {
  value = google_dataproc_cluster.analytics_cluster.region
}
