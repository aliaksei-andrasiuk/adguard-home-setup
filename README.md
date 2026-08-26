# AdGuard Home Setup

Reproducible Docker-based AdGuard Home setup for Ubuntu home servers.

The repository is intentionally public and contains **no live AdGuard configuration, passwords, password hashes, query logs, or private keys**.

Host-specific values live in `.env`, which is ignored by Git. If you want one-command disaster recovery, encrypt that file with [`age`](https://github.com/FiloSottile/age) and commit only `.env.age`.

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

`AdGuardHome.yaml` is **not backed up**. On a fresh installation AdGuard Home creates it itself. The bootstrap script uses the official first-install API and asks for a new local admin username/password interactively; those credentials are never written to `.env` or Git.

## First-time personal setup

Clone the repository:

```bash
git clone https://github.com/aliaksei-andrasiuk/adguard-home-setup.git
cd adguard-home-setup
```

Create your local environment:

```bash
cp .env.example .env
nano .env
```

Encrypt it with a passphrase:

```bash
./scripts/encrypt-env.sh
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
./scripts/bootstrap.sh
```

If `.env` does not exist but `.env.age` does, the script:

1. installs `age` if required;
2. asks for the encryption passphrase and decrypts `.env`;
3. validates the configured interface and server IP;
4. installs Docker/Compose if they are missing;
5. creates the AdGuard Home persistent directories;
6. starts the official `adguard/adguardhome` container with host networking;
7. on a fresh AdGuard installation, asks for a **new** local AdGuard admin username/password and completes the initial setup through AdGuard Home's install API;
8. verifies DNS and web listeners;
9. prints the remaining router/TV settings that cannot be automated from the server.

If AdGuard Home is already configured, `bootstrap.sh` does not overwrite `AdGuardHome.yaml`; it simply ensures the declared container is running.

## Verify

```bash
./scripts/verify.sh
```

## Print manual network steps

```bash
./scripts/print-network-steps.sh
```

See [`docs/network.md`](docs/network.md) for the router and Samsung TV steps.

## Security notes

- `.env` is gitignored.
- `.env.age` may be committed publicly, but its confidentiality depends on the strength of your age passphrase.
- Do not put AdGuard admin passwords, password hashes, TLS private keys, API tokens, query logs, router backups, or Tailscale credentials in `.env`.
- This setup binds DNS and the AdGuard web interface to `SERVER_IP`, not `0.0.0.0`, so it can coexist with Ubuntu `systemd-resolved` listening on loopback.
- No firewall, DHCP, IPv6 RA/RDNSS, NetworkManager, or `systemd-resolved` settings are changed automatically.

## Tested topology

The original setup was built for Ubuntu 26.04 LTS with Docker Compose, an ISP router providing DHCP, and a Samsung Tizen TV using a manually configured IPv4 DNS server. All machine-specific values are kept outside the public source files.
