locals {
  user_data = templatefile("${path.module}/../cloud-init/primary.yaml.tftpl", {
    clave_version          = var.clave_version
    clave_release_base_url = var.clave_release_base_url
    clave_target           = var.clave_target
    public_hostname        = var.public_hostname
    acme_email             = var.acme_email
    epoch_cadence_seconds  = var.epoch_cadence_seconds
    pin_suffix_list        = var.pin_suffix_list
    clave_install          = file("${path.module}/../../vm/clave-install")
    clave_backup           = file("${path.module}/../../vm/clave-backup")
    clave_restore          = file("${path.module}/../../vm/clave-restore")
    clave_verify           = file("${path.module}/../../vm/clave-verify")
    verify_checkpoint      = file("${path.module}/../../scripts/verify-checkpoint.py")
  })
}

data "hcloud_ssh_key" "operator" {
  name = var.ssh_key_name
}

resource "hcloud_firewall" "public" {
  name = "${var.name}-public"

  rule {
    description = "operator SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.operator_cidrs
  }

  rule {
    description = "HTTP for certificate issuance and redirects"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "aggregator" {
  name         = var.name
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [data.hcloud_ssh_key.operator.id]
  firewall_ids = [hcloud_firewall.public.id]
  user_data    = local.user_data

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
}
