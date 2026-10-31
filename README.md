# AWS VPC Peering – Private Connectivity Between Two VPCs

EWB Cloud Labs · AWS Architect Associate · Project 01
Region: **ap-south-1 (Mumbai)** · Completed: **31 October 2026**

Two VPCs, three EC2 instances and one VPC peering connection. Two private application servers (one in each VPC) talk to each other over their private IPs only. A single bastion host in VPC A is the only machine with a public IP, and it's used for administration.

📄 **Full report:** [Ayush_Sharma_EWB_VPC_Peering.pdf](Ayush_Sharma_EWB_VPC_Peering.pdf)

---

## Architecture

```
                        Laptop
                          │ SSH :22 (only from my IP /32)
                          ▼
                   Internet gateway (ewb-igw-a)
┌──────────── ewb-vpc-a 10.10.0.0/16 ───────────┐        ┌──────── ewb-vpc-b 10.20.0.0/16 ────────┐
│ ewb-a-public 10.10.1.0/24                     │        │ (no internet gateway)                  │
│   ewb-bastion 10.10.1.10 + public IPv4        │        │                                        │
│                                               │  pcx   │                                        │
│ ewb-a-private 10.10.2.0/24                    │◄──────►│ ewb-b-private 10.20.1.0/24             │
│   ewb-app-a 10.10.2.10 (no public IP)         │        │   ewb-app-b 10.20.1.10 (no public IP)  │
└───────────────────────────────────────────────┘        └────────────────────────────────────────┘
```

- **Admin path:** laptop → bastion → App-A / App-B using SSH `ProxyJump`. The private key never leaves the laptop.
- **Project traffic:** App-A ↔ App-B over private IPs through the peering connection.

## IP plan

| Resource | Name | CIDR / IP |
|---|---|---|
| VPC A | `ewb-vpc-a` | 10.10.0.0/16 |
| Public subnet | `ewb-a-public` | 10.10.1.0/24 |
| Private subnet A | `ewb-a-private` | 10.10.2.0/24 |
| VPC B | `ewb-vpc-b` | 10.20.0.0/16 |
| Private subnet B | `ewb-b-private` | 10.20.1.0/24 |
| Bastion | `ewb-bastion` | 10.10.1.10 + public IP |
| App-A | `ewb-app-a` | 10.10.2.10 |
| App-B | `ewb-app-b` | 10.20.1.10 |

## Route tables

| Route table | Subnet | Routes |
|---|---|---|
| `ewb-rt-a-public` | ewb-a-public | 10.10.0.0/16 → local · 0.0.0.0/0 → IGW · 10.20.0.0/16 → pcx |
| `ewb-rt-a-private` | ewb-a-private | 10.10.0.0/16 → local · 10.20.0.0/16 → pcx |
| `ewb-rt-b-private` | ewb-b-private | 10.20.0.0/16 → local · 10.10.0.0/16 → pcx |

The public route table also needs the peering route. With ProxyJump, the bastion itself opens the connection to App-B.

## Security groups (inbound)

| Group | Rule | Source |
|---|---|---|
| `ewb-sg-bastion` | TCP 22 | my public IP /32 |
| `ewb-sg-app-a` | TCP 22 | 10.10.1.10/32 (bastion) |
| `ewb-sg-app-a` | ICMP echo request | 10.20.1.10/32 (App-B) |
| `ewb-sg-app-b` | TCP 22 | 10.10.1.10/32 (bastion) |
| `ewb-sg-app-b` | ICMP echo request | 10.10.2.10/32 (App-A) |

No rule is open to `0.0.0.0/0`. Outbound rules are left as the default (allow all), and the network ACLs are the default ones.

## Test results

| # | Test | Expected | Result |
|---|---|---|---|
| 01 | App-A → 10.20.1.10 before peering | no replies | ✅ 100% loss |
| – | App-A → 10.20.1.10, peering active but no routes | no replies | ✅ 100% loss |
| 02 | App-A → App-B after routes | 4/4 replies | ✅ 0% loss |
| 03 | App-B → App-A after routes | 4/4 replies | ✅ 0% loss |
| 04 | `ssh ewb-app-b` through bastion | shell on App-B | ✅ logged in as ec2-user |
| 05 | Public IP on App-A / App-B | none | ✅ none |
| 06 | Remove App-B ICMP rule → ping, restore → ping | fail, then recover | ✅ 100% loss → 0% loss |

Raw terminal output for every test is in [`evidence/`](evidence).

## Repository layout

| File | What it does |
|---|---|
| `build.sh` | Creates both VPCs, subnets, IGW, route tables, security groups, key pair and the 3 instances. Writes all resource IDs to `ids.env` and generates `ssh_config`. |
| `test.sh` | Baseline test → creates and accepts the peering → adds routes → runs all verification tests and the controlled failure. Saves output to `evidence/` and checks each result. |
| `cleanup.sh` | Deletes everything in reverse order, then checks that no project-tagged resource is left. |
| `gen_report.js` | Builds `report.html` from the evidence files (printed to PDF with Edge/Chrome). |
| `evidence/` | Terminal output from the actual run (resource IDs, route tables, rules, pings, SSH, cleanup). |

## How to run it

Requirements: AWS CLI v2 signed in to an account, Git Bash/WSL/Linux with OpenSSH, and Node.js (only for the report).

```bash
bash build.sh       # ~3 min, waits for instance status checks
bash test.sh        # prints ALL TESTS MATCH EXPECTED RESULTS
bash cleanup.sh     # removes everything, all counts should be 0
node gen_report.js  # optional: rebuild report.html
```

`build.sh` refuses to run if `ids.env` still exists. That means resources from an earlier build haven't been cleaned up yet. Cost for one run is a few cents (3 × t3.micro + 1 public IPv4 for under an hour, no NAT gateway).

## Key points

1. **Peering being Active is not enough.** Both sides need a route to the `pcx`, and the destination security group has to allow the traffic (shown in the "no routes" test).
2. **The return route matters.** Without `10.10.0.0/16 → pcx` in VPC B, replies have no way back.
3. **The App-B SSH source is the bastion's private IP.** ProxyJump opens a new connection from the bastion, so App-B never sees the laptop's IP.
4. **Peering is non-transitive and has no edge-to-edge routing.** VPC B can't use VPC A's internet gateway.

## Cleanup

All resources were deleted after testing. See [`evidence/20_cleanup.txt`](evidence/20_cleanup.txt) and [`evidence/21_cleanup_verify.txt`](evidence/21_cleanup_verify.txt). The public IP in the evidence is masked (`49.36.191.x`).
