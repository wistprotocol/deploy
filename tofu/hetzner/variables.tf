variable "name" {
  type        = string
  description = "Server name, also the prefix of the firewall's name."
  default     = "clave"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.name))
    error_message = "Lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "location" {
  type        = string
  description = "Hetzner location (fsn1, nbg1, hel1, ash, hil, sin)."
  default     = "fsn1"
}

variable "server_type" {
  type        = string
  description = "Plan of the server; confirm names and prices with `hcloud server-type list`."
  default     = "cx23"
}

variable "image" {
  type        = string
  description = "Operating system image; the cloud-init here targets Ubuntu 24.04."
  default     = "ubuntu-24.04"
}

variable "primary_ipv4_id" {
  type        = number
  description = "ID of a primary IPv4 the caller created in the server's location, assigned to the server instead of an automatically allocated one: its address is known before the server exists and outlives a server replacement. Null: the server allocates its own, deleted with it."
  default     = null
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an SSH key already registered in the Hetzner project; it is installed for root."
}

variable "operator_cidrs" {
  type        = list(string)
  description = "Source addresses allowed to reach port 22, in CIDR notation (IPv4 or IPv6)."

  validation {
    condition     = length(var.operator_cidrs) > 0
    error_message = "At least one operator address is required, or no one can log in."
  }
}

variable "clave_version" {
  type        = string
  description = "Git tag of the Clave release to install, e.g. v0.1.0; README.md describes the release assets."

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+([-+][0-9A-Za-z.-]+)?$", var.clave_version))
    error_message = "A release tag such as v0.1.0."
  }
}

variable "clave_release_base_url" {
  type        = string
  description = "Base URL under which <tag>/<asset> is downloaded."
  default     = "https://github.com/wistprotocol/clave/releases/download"
}

variable "clave_target" {
  type        = string
  description = "Rust target triple in the release asset name."
  default     = "x86_64-unknown-linux-musl"
}

variable "public_hostname" {
  type        = string
  description = "DNS name that resolves to the server; it becomes the Log's identity and gets a publicly trusted certificate. Empty: the server's IPv4 is the identity and the certificate comes from the server's own CA (test hosts only)."
  default     = ""
}

variable "acme_email" {
  type        = string
  description = "Contact address given to the certificate authority when public_hostname is set."
  default     = ""
}

variable "epoch_cadence_seconds" {
  type        = number
  description = "Epoch cadence passed to the Log at initialization."
  default     = 3600
}

variable "pin_suffix_list" {
  type        = bool
  description = "Download the Public Suffix List at first boot and pin it for Epoch 0."
  default     = true
}
