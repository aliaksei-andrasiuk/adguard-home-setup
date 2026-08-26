# Manual network configuration

The server-side setup is automated, but the router and TV live outside the Ubuntu host and must be configured manually.

All values below come from `.env`. To print the exact values for the current machine:

```bash
bash scripts/print-network-steps.sh
```

## 1. Router / PlayBox

Keep the router DHCP server enabled for this topology.

Create a DHCP reservation for the AdGuard Home server:

```text
IP  = SERVER_IP
MAC = SERVER_MAC
```

Create a DHCP reservation for the Samsung TV:

```text
IP  = TV_IP
MAC = TV_MAC
```

Do not change router DHCP, IPv6 RA/RDNSS, or DNS relay settings as part of this setup.

## 2. Samsung Tizen TV

Some Samsung Tizen versions fail to retain a manually configured DNS server while the IPv4 address remains automatic. The working setup for the original TV was to make both IPv4 and DNS manual.

Set:

```text
IP Setting: Enter manually
IP address:  TV_IP
Subnet mask: LAN_NETMASK
Gateway:     ROUTER_IP

DNS Setting: Enter manually
DNS server:  SERVER_IP
```

Exit the IP settings screen, reopen it, and confirm that the manual values were retained.

## 3. Verify from AdGuard Home

Open:

```text
http://SERVER_IP:ADGUARD_WEB_PORT
```

In **Query Log**, filter by `TV_IP`. Open a few pages or apps on the TV and confirm that DNS queries appear from that client.

For a deterministic test, temporarily add a custom filtering rule for a harmless test domain, confirm that it is blocked on the TV, then remove the rule.

## 4. Recovery fallback

If AdGuard Home is unavailable and the TV loses DNS resolution, temporarily switch the Samsung TV DNS setting back to **Get automatically**. This bypasses AdGuard Home and restores the router-provided DNS path.

## IPv6 note

The original ISP router advertises its own IPv6 recursive DNS servers via Router Advertisement (RDNSS). This repository deliberately does not attempt to override or spoof those advertisements. The current target is the Samsung TV using a manually configured IPv4 DNS server; network-wide DNS enforcement is outside the scope of this setup.
