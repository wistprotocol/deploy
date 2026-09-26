output "ipv4" {
  value = hcloud_server.aggregator.ipv4_address
}

output "ipv6" {
  value = hcloud_server.aggregator.ipv6_address
}

output "base_url" {
  description = "Where the aggregator answers over HTTPS."
  value       = "https://${var.public_hostname != "" ? var.public_hostname : hcloud_server.aggregator.ipv4_address}"
}

output "ssh" {
  value = "ssh root@${hcloud_server.aggregator.ipv4_address}"
}

output "firewall_id" {
  value = hcloud_firewall.public.id
}
