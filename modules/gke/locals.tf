locals {
  node_sa_id    = "${var.name_prefix}-gke-node-sa"
  workload_pool = "${var.project_id}.svc.id.goog"
}
