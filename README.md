# AdGuard Home Setup

Reproducible Docker-based AdGuard Home setup for Ubuntu home servers.

The repository is intentionally public and contains **no live AdGuard configuration, passwords, password hashes, query logs, or private keys**.

Host-specific values live in `.env`, which is ignored by Git. For one-command disaster recovery, encrypt that file with [`age`](https://github.com/FiloSottile/age) and commit only `.env.age`.

## Recovery model

```text
public Git repository
├── compose.yaml
├── .env.example
├── .env.age          # optional encrypted personal environment
├── scripts/
└── docs/

local machine only
└── .env              # decrypted values, never committed
```

`AdGuardHome.yaml` is intentionally **not backed up**. On a fresh installation AdGuard Home creates it itself. `bootstrap.sh` uses AdGuard Home's first-install API and asks for a new local admin username/password interactively; those credentials are never written to `.env` or Git.

## Environment variables

The reusable configuration lives in `.env`:

```dotenv
SERVER_IP=192.168.0.216
SERVER_INTERFACE=enp3s0
SERVER_MAC=
ROUTER_IP=192.168.0.1
LAN_NETMASK=255.255.255.0

ADGUARD_IMAGE=adguard/adguardhome:latest
ADGUARD_DATA_DIR=/opt/adguardhome
ADGUARD_WEB_PORT=80
ADGUARD_DNS_PORT=53
ADGUARD_LANGUAGE=en

TV_IP=192.168.0.71
TV_MAC=
```

Do not add AdGuard admin credentials to this file.

## First-time personal setup

Clone the repository:

```bash
git clone https://github.com/aliaksei-andrasiuk/adguard-home-setup.git
cd adguard-home-setup
```

Create `.env`. `init-env.sh` detects the active interface, current IPv4 address, gateway, and server MAC where possible:

```bash
bash scripts/init-env.sh
nano .env
```

Fill any remaining values, for example the TV MAC address.

Encrypt the environment with a passphrase:

```bash
bash scripts/encrypt-env.sh
```

This creates `.env.age`. The plaintext `.env` remains local and is ignored by Git.

Commit only the encrypted file:

```bash
git add .env.age
git commit -m "Add encrypted home environment"
git push
```

Use a strong passphrase and keep it in a password manager. The passphrase is the only thing needed to decrypt `.env.age`; it must **not** be stored in this repository.

## Disaster recovery

On a fresh Ubuntu machine:

```bash
git clone https://github.com/aliaksei-andrasiuk/adguard-home-setup.git
cd adguard-home-setup
bash scripts/bootstrap.sh
```

If `.env` does not exist but `.env.age` does, the script:

1. installs `age` if required;
2. asks for the encryption passphrase and decrypts `.env` locally;
3. validates the configured interface and server IP;
4. installs Docker/Compose if they are missing;
5. creates the AdGuard Home persistent directories;
6. starts the official AdGuard Home container with host networking;
7. on a fresh AdGuard installation, asks for a **new** local admin username/password and completes initial setup through AdGuard Home's install API;
8. verifies DNS and web listeners;
9. prints the remaining router/TV settings that cannot be automated from the server.

If AdGuard Home is already configured, `bootstrap.sh` leaves the existing `AdGuardHome.yaml` unchanged and simply ensures the declared container is running.

## Verify

```bash
bash scripts/verify.sh
```

## Print manual network steps

```bash
bash scripts/print-network-steps.sh
```

See [`docs/network.md`](docs/network.md) for the router and Samsung TV steps.

## Security notes

- `.env` is gitignored.
- `.env.age` may be committed publicly, but its confidentiality depends on the strength of your age passphrase.
- Do not put AdGuard admin passwords, password hashes, TLS private keys, API tokens, query logs, router backups, or Tailscale credentials in `.env`.
- This setup binds DNS and the AdGuard web interface to `SERVER_IP`, not `0.0.0.0`, so it can coexist with Ubuntu `systemd-resolved` listening on loopback.
- No firewall, DHCP, IPv6 RA/RDNSS, NetworkManager, or `systemd-resolved` settings are changed automatically.
- The bootstrap refuses to continue if `SERVER_IP` is not already assigned to `SERVER_INTERFACE`. This is deliberate: router reservations or host networking must be correct before DNS is restored.

## Tested topology

The original setup was built for Ubuntu 26.04 LTS with Docker Compose, an ISP router providing DHCP, and a Samsung Tizen TV using a manually configured IPv4 DNS server. All machine-specific values are kept outside the public source files.
