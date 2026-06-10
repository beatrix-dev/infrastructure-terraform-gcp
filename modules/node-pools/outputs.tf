output "node_pool_ids" {
  description = "Map of node pool logical names to their IDs"
  value       = { for k, np in google_container_node_pool.pools : k => np.id }
}

output "node_pool_instance_group_urls" {
  description = "Map of node pool names to their managed instance group URLs"
  value       = { for k, np in google_container_node_pool.pools : k => np.managed_instance_group_urls }
}
