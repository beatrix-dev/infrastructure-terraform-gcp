# Disabled along with module.gke / module.container_registry in main.tf —
# uncomment together when back to GKE-based testing.
#
# output "cluster_name" {
#   value       = module.gke.cluster_name
#   description = "GKE cluster name"
# }
#
# output "cluster_endpoint" {
#   value       = module.gke.cluster_endpoint
#   description = "GKE cluster endpoint"
#   sensitive   = true
# }
#
# output "cluster_location" {
#   value       = var.region
#   description = "GKE cluster location (region)"
# }
#
# output "node_service_account_email" {
#   value       = module.gke.node_service_account_email
#   description = "Email of the GKE node service account"
# }
#
# output "kubeconfig_command" {
#   value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
#   description = "Command to update kubeconfig"
# }
#
# output "container_registry_url" {
#   value       = module.container_registry.repository_url
#   description = "Docker-pull URL for the container registry"
# }

output "instance_zones" {
  value       = module.instance.instance_zones
  description = "Zone each test instance actually landed in"
}

output "instance_internal_ips" {
  value       = module.instance.internal_ips
  description = "Internal IPs of test instances"
}

output "instance_external_ips" {
  value       = module.instance.external_ips
  description = "External IPs of test instances (null unless assign_external_ip = true)"
}

output "instance_ssh_commands" {
  value       = module.instance.ssh_commands
  description = "gcloud SSH-over-IAP commands for each test instance"
}

# ---------------------------------------------------------------------------
# AWS-side setup — this repo only has a google provider, so the AWS half of
# the VPN (security groups + routing) has to be done by hand, and it has to
# use the SAME routing option (Static vs Dynamic) as var.vpn_routing_mode —
# AWS won't let one side of a connection be BGP and the other static.
# ---------------------------------------------------------------------------
output "aws_side_setup_required" {
  description = "Manual AWS-side steps needed for full bidirectional connectivity — not managed by this repo"
  value = join("\n", concat(
    [
      "1. Security groups (both AWS VPN connections' target resources):",
      "   add an inbound rule allowing traffic from ${module.vpc.subnet_cidr} (this VPC's",
      "   subnet CIDR — GCP allows ALL protocols/ports from vpn_peer_cidr, so match on",
      "   the AWS side whatever ports/protocols your workloads actually need).",
      "2. Network ACLs (if the AWS subnets use custom NACLs, not just the default):",
      "   allow ${module.vpc.subnet_cidr} in both the inbound and outbound rule sets.",
    ],
    var.vpn_routing_mode == "DYNAMIC" ? [
      "3. Both AWS VPN connections must be created with routing option \"Dynamic (BGP)\".",
      "4. Route tables: on every AWS route table associated with subnets that need to",
      "   reach GCP, enable \"Route Propagation\" for both Virtual Private Gateway",
      "   attachments used by the two VPN connections. This lets AWS learn the GCP",
      "   subnet CIDR (${module.vpc.subnet_cidr}) automatically via BGP.",
      "5. Once both AWS VPN connections show \"UP\" and BGP status \"UP\" for all 4",
      "   tunnels, confirm propagated routes appear in the AWS route table pointing",
      "   at the VGW with the GCP subnet CIDR as the destination.",
      ] : [
      "3. Both AWS VPN connections must be created with routing option \"Static\" — this",
      "   is what this repo's vpn_routing_mode = \"STATIC\" default matches.",
      "4. When creating/editing each AWS VPN connection, add ${module.vpc.subnet_cidr}",
      "   (or whatever CIDR(s) you set in vpn_static_route_destination_ranges) as a",
      "   static route so AWS knows to send that traffic down the tunnels.",
      "5. Route tables: on every AWS route table associated with subnets that need to",
      "   reach GCP, add a static route for ${module.vpc.subnet_cidr} with the target",
      "   set to the Virtual Private Gateway used by that connection.",
    ]
  ))
}
