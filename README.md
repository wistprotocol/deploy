# deploy

Turns an Ubuntu host into a WIST aggregator ([Clave](https://github.com/wistprotocol/clave))
serving its own Log over HTTPS, and rents such a host with one command where a provider
module exists. The host layer (`vm/`, `tofu/cloud-init/`) works on any Ubuntu 24.04 machine
with systemd: a home server, a VPS, bare metal. Provider modules (`tofu/<provider>/`) rent a
machine and feed it that layer; today there is one, Hetzner Cloud. Every install creates its
own Log identity and freshly generated signing keys; no key or token is ever placed in this
repository.

## Any host

Requirements: Ubuntu 24.04 with systemd and root access; a DNS name pointing at the host,
which becomes the Log's identity and the name on its certificate; ports 80 and 443 reachable
from the internet (port forwarding on a home connection); outbound access to fetch publishers'
Feeds and the release.

1. Copy `vm/*` to `/usr/local/sbin/` (mode 0755) and `scripts/verify-checkpoint.py` to
   `/usr/local/lib/clave/verify-checkpoint.py`.
2. Write `/etc/clave/env`:
   ```
   CLAVE_VERSION=v0.1.0
   CLAVE_RELEASE_BASE_URL=https://github.com/wistprotocol/clave/releases/download
   CLAVE_TARGET=x86_64-unknown-linux-musl
   PUBLIC_HOSTNAME=log.example.org
   ACME_EMAIL=you@example.org
   EPOCH_CADENCE_SECONDS=3600
   PIN_SUFFIX_LIST=true
   ```
3. Run `clave-install` as root. It installs the packages, downloads the release, verifies it,
   initializes the Log, starts the unit and verifies the served head Checkpoint.
4. From another machine: `scripts/verify.sh https://log.example.org`.

The release is a Git tag `vX.Y.Z` on the Clave repository equal to `v` + the crate's Cargo
version, carrying `clave-vX.Y.Z-<target>.tar.gz` (the `clave` binary at the archive root) and
`SHA256SUMS` (`<sha256>  <asset>` lines). `CLAVE_RELEASE_BASE_URL` accepts any base URL
serving `<tag>/<asset>`, a file URL included.

## On the host

The aggregator runs as the `clave` system user under `clave.service`, bound to
`127.0.0.1:8080`, with everything it owns under `/var/lib/clave` (store `clave.sqlite`, key
seeds under `keys/`, the published Log, Payloads and Snapshots). Caddy terminates TLS on 443
and proxies to it. The unit logs `clave --version` at every start, so `journalctl -u clave`
tells which revision serves.

| Command | Effect |
|---------|--------|
| `clave-install [TAG]` | Downloads `TAG` (default: `CLAVE_VERSION`), checks its digest and that the binary reports that version; when a store exists, stops the unit and runs `clave-backup` first; installs the binary, unit and Caddy configuration; initializes a new Log when no store exists (identity: the served host; fresh keys; Public Suffix List pinned when enabled); starts the unit; runs `clave-verify`. |
| `clave-backup [--keep-stopped] [DIR]` | Stops the unit, archives `/var/lib/clave` to `DIR/clave-<UTC>.tar.zst` (default `/var/backups/clave`) with a `.sha256` sidecar, starts the unit again unless `--keep-stopped`, prints the archive path. |
| `clave-restore ARCHIVE` | Checks the sidecar, stops the unit, moves the current data directory aside as `/var/lib/clave.replaced-<UTC>` (never deleted), extracts the archive, starts and verifies. The restored Log keeps the archive's identity and keys. |
| `clave-verify` | Waits for the unit, fetches Anchor and head Checkpoint through the proxy, verifies the Checkpoint under the Anchor's genesis key, prints identity, tree size and binary version. |

### Upgrade

`clave-install vB`. It stops the unit, backs up the whole data directory, replaces the
binary, writes the unit and proxy configuration again, starts and verifies. The binary can
be rolled back with `clave-install vA` only while the store is readable by `vA`: schema
migration is forward-only, and an older binary may refuse a migrated store; the backup taken
before the upgrade is the way back.

### Restore

On a fresh host, install first, then copy the archive and run `clave-restore ARCHIVE`. The
host then serves the archived Log, not the identity its own install created, so move the DNS
record to it.

The store is never restored below the last published Checkpoint: signing again from an older
state would publish a second Checkpoint for an already published Epoch (WIST-3 §5,
Equivocation). Restore an older archive only to a host that is not the published Log, or
recover the published Log's files first.

### TLS

With `PUBLIC_HOSTNAME` set, Caddy obtains a publicly trusted certificate for it
(`ACME_EMAIL` is the contact address); the DNS record must point at the host before issuance
succeeds, and Caddy retries until it does. Without it, for test hosts only, the served address
is `SERVED_HOST` from the environment file when set, else the Hetzner metadata service's
public IPv4, else the source address of the host's default route; Caddy then serves a
certificate from its own CA, whose root `scripts/verify.sh` fetches over SSH into `run/` (or
reads from `VERIFY_CA`).

## Hetzner Cloud

`tofu/hetzner/` creates a firewall (22 from `operator_cidrs`, 80 and 443 from anywhere,
ICMP) and one server whose cloud-init runs `clave-install` at first boot; `destroy` removes
both, the server's primary IPv4 included. It works as a root configuration or as a module.

Prerequisites: a Hetzner Cloud project; an API token with read and write scope in the
environment (`export HCLOUD_TOKEN=...`), never in a file here; an SSH key registered in the
project (`ssh_key_name`), installed for `root`; [OpenTofu](https://opentofu.org/docs/intro/install/)
≥ 1.8, `ssh`, and for `scripts/verify.sh` `curl`, `jq` and `python3` with `cryptography`.

```
cd tofu/hetzner
tofu init
tofu apply -var-file=my.tfvars          # example.tfvars lists the variables
ssh root@$(tofu output -raw ipv4) cloud-init status --wait
../../scripts/verify.sh $(tofu output -raw base_url)
```

`apply` returns when the server exists; cloud-init then installs, which takes a few minutes.
`journalctl -u clave` and `/var/log/cloud-init-output.log` on the server hold the install
log. `variables.tf` documents every variable; the plan defaults to a small shared-CPU server,
and the DNS record for `public_hostname` should point at the server's address as soon as
`apply` prints it.

## Other providers

A provider module is a directory under `tofu/` that creates a machine, opens 22, 80 and 443,
and passes `tofu/cloud-init/primary.yaml.tftpl` rendered with the same variables as the
machine's user data; `tofu/hetzner/main.tf` shows the rendering. Hosts without cloud-init
follow [Any host](#any-host).
