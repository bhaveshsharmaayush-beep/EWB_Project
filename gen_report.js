const fs = require('fs');
const path = require('path');
const dir = __dirname;
const ev = f => { const p = path.join(dir, 'evidence', f); return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : '(not yet captured)'; };
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const clean = s => s.split('\n').filter(l => !/post-quantum|store now|pq\.html|Permanently added/.test(l)).join('\n').trim();
const pre = (f, label) => `<div class="fig"><div class="cap">${label}</div><pre>${esc(clean(ev(f)))}</pre></div>`;
// cleanup.sh archives ids.env into evidence/, so fall back to that copy.
const idsFile = fs.existsSync(path.join(dir, 'ids.env')) ? path.join(dir, 'ids.env') : path.join(dir, 'evidence', '00_resource_ids.txt');
const ids = Object.fromEntries(fs.readFileSync(idsFile, 'utf8').trim().split('\n').map(l => l.split('=')));
const NAME = process.env.STUDENT || 'Ayush Sharma';
const BATCH = process.env.BATCH || '____________';

const html = `<!doctype html><html><head><meta charset="utf-8"><title>${NAME} - EWB VPC Peering</title><style>
body{font-family:Segoe UI,Arial,sans-serif;font-size:10.5pt;color:#1a1a1a;margin:0}
.page{padding:18mm 16mm;page-break-after:always}
h1{font-size:24pt;margin:0 0 6mm}h2{font-size:15pt;border-bottom:2px solid #f90;padding-bottom:2mm;margin-top:0}h3{font-size:11.5pt;margin:5mm 0 2mm}
table{border-collapse:collapse;width:100%;margin:2mm 0 4mm}td,th{border:1px solid #bbb;padding:3px 6px;text-align:left;font-size:9.5pt}th{background:#f2f2f2}
pre{background:#0f172a;color:#e2e8f0;padding:3mm;font-size:7.6pt;white-space:pre-wrap;word-break:break-all;margin:0;border-radius:3px}
.fig{margin:3mm 0 5mm;page-break-inside:avoid}.cap{font-weight:600;font-size:9.5pt;margin-bottom:1mm;color:#333}
.cover{display:flex;flex-direction:column;justify-content:center;height:240mm}.cover td{font-size:11.5pt;padding:6px 10px}
.ok{color:#0a7a2f;font-weight:700}.bad{color:#b00020;font-weight:700}
svg text{font-family:Segoe UI,Arial}
</style></head><body>

<div class="page cover">
<h1>AWS VPC Peering &mdash; Private Connectivity Between Two VPCs</h1>
<p style="font-size:12pt;margin-bottom:10mm">EWB Cloud Labs &middot; AWS Architect Associate &middot; Project 01</p>
<table style="width:70%">
<tr><th>Name</th><td>${NAME}</td></tr>
<tr><th>Batch</th><td>${BATCH}</td></tr>
<tr><th>Project title</th><td>AWS VPC Peering</td></tr>
<tr><th>Region</th><td>Asia Pacific (Mumbai) &ndash; ap-south-1 (AZ ap-south-1a)</td></tr>
<tr><th>Completion date</th><td>31 October 2026</td></tr>
</table>
</div>

<div class="page">
<h2>1. Architecture</h2>
<svg viewBox="0 0 760 330" width="100%">
<rect x="300" y="5" width="160" height="34" rx="6" fill="#eef" stroke="#557"/><text x="380" y="27" text-anchor="middle" font-size="12">Laptop (${ids.MYIP})</text>
<line x1="380" y1="39" x2="280" y2="59" stroke="#555" stroke-dasharray="4"/><text x="335" y="52" font-size="10">SSH / 22</text>
<rect x="10" y="70" width="330" height="250" rx="8" fill="#fff7ec" stroke="#f90" stroke-width="2"/>
<text x="20" y="90" font-size="13" font-weight="bold">ewb-vpc-a 10.10.0.0/16</text>
<rect x="230" y="59" width="100" height="22" rx="4" fill="#f90"/><text x="280" y="74" text-anchor="middle" font-size="10" fill="#fff">ewb-igw-a</text>
<rect x="25" y="105" width="300" height="90" rx="6" fill="#e9f7ee" stroke="#2a7"/>
<text x="35" y="123" font-size="11">ewb-a-public 10.10.1.0/24 (rt: 0.0.0.0/0 &#8594; IGW)</text>
<rect x="60" y="135" width="220" height="45" rx="5" fill="#fff" stroke="#333"/><text x="170" y="155" text-anchor="middle" font-size="11">ewb-bastion 10.10.1.10</text><text x="170" y="171" text-anchor="middle" font-size="10">public ${ids.BASTION_IP}</text>
<rect x="25" y="210" width="300" height="95" rx="6" fill="#eaf1fb" stroke="#36c"/>
<text x="35" y="228" font-size="11">ewb-a-private 10.10.2.0/24 (no internet route)</text>
<rect x="60" y="242" width="220" height="45" rx="5" fill="#fff" stroke="#333"/><text x="170" y="262" text-anchor="middle" font-size="11">ewb-app-a 10.10.2.10</text><text x="170" y="278" text-anchor="middle" font-size="10">no public IP</text>
<rect x="420" y="70" width="330" height="250" rx="8" fill="#f3eefc" stroke="#73c" stroke-width="2"/>
<text x="430" y="90" font-size="13" font-weight="bold">ewb-vpc-b 10.20.0.0/16 (no IGW)</text>
<rect x="435" y="210" width="300" height="95" rx="6" fill="#eaf1fb" stroke="#36c"/>
<text x="445" y="228" font-size="11">ewb-b-private 10.20.1.0/24</text>
<rect x="470" y="242" width="220" height="45" rx="5" fill="#fff" stroke="#333"/><text x="580" y="262" text-anchor="middle" font-size="11">ewb-app-b 10.20.1.10</text><text x="580" y="278" text-anchor="middle" font-size="10">no public IP</text>
<line x1="340" y1="200" x2="420" y2="200" stroke="#c30" stroke-width="4"/><text x="380" y="192" text-anchor="middle" font-size="10" fill="#c30">${ids.PCX}</text><text x="380" y="215" text-anchor="middle" font-size="10" fill="#c30">ewb-a-b-peer</text>
<line x1="280" y1="265" x2="470" y2="265" stroke="#c30" stroke-dasharray="5"/><text x="375" y="258" text-anchor="middle" font-size="9">ICMP App-A &#8596; App-B</text>
</svg>
<p><b>Administration path:</b> laptop &#8594; bastion (public IP) &#8594; App-A or App-B, using SSH ProxyJump. The key stays on the laptop. <b>Project traffic:</b> App-A &#8596; App-B over private IPs through the peering connection.</p>

<h3>Resource inventory (actual IDs)</h3>
<table>
<tr><th>Resource</th><th>Name tag</th><th>ID</th><th>CIDR / IP</th></tr>
<tr><td>VPC A</td><td>ewb-vpc-a</td><td>${ids.VPC_A}</td><td>10.10.0.0/16</td></tr>
<tr><td>Public subnet</td><td>ewb-a-public</td><td>${ids.SUB_A_PUB}</td><td>10.10.1.0/24</td></tr>
<tr><td>Private subnet A</td><td>ewb-a-private</td><td>${ids.SUB_A_PRIV}</td><td>10.10.2.0/24</td></tr>
<tr><td>VPC B</td><td>ewb-vpc-b</td><td>${ids.VPC_B}</td><td>10.20.0.0/16</td></tr>
<tr><td>Private subnet B</td><td>ewb-b-private</td><td>${ids.SUB_B_PRIV}</td><td>10.20.1.0/24</td></tr>
<tr><td>Internet gateway</td><td>ewb-igw-a</td><td>${ids.IGW}</td><td>attached to VPC A</td></tr>
<tr><td>Route table</td><td>ewb-rt-a-public</td><td>${ids.RT_A_PUB}</td><td>&#8594; ewb-a-public</td></tr>
<tr><td>Route table</td><td>ewb-rt-a-private</td><td>${ids.RT_A_PRIV}</td><td>&#8594; ewb-a-private</td></tr>
<tr><td>Route table</td><td>ewb-rt-b-private</td><td>${ids.RT_B_PRIV}</td><td>&#8594; ewb-b-private</td></tr>
<tr><td>Security group</td><td>ewb-sg-bastion</td><td>${ids.SG_BASTION}</td><td>VPC A</td></tr>
<tr><td>Security group</td><td>ewb-sg-app-a</td><td>${ids.SG_APP_A}</td><td>VPC A</td></tr>
<tr><td>Security group</td><td>ewb-sg-app-b</td><td>${ids.SG_APP_B}</td><td>VPC B</td></tr>
<tr><td>Peering connection</td><td>ewb-a-b-peer</td><td>${ids.PCX}</td><td>A (requester) &#8596; B (accepter)</td></tr>
<tr><td>EC2 instance</td><td>ewb-bastion</td><td>${ids.I_BASTION}</td><td>10.10.1.10 + ${ids.BASTION_IP}</td></tr>
<tr><td>EC2 instance</td><td>ewb-app-a</td><td>${ids.I_APP_A}</td><td>10.10.2.10 (no public IP)</td></tr>
<tr><td>EC2 instance</td><td>ewb-app-b</td><td>${ids.I_APP_B}</td><td>10.20.1.10 (no public IP)</td></tr>
</table>
<p>AMI: Amazon Linux 2023 (${ids.AMI}), t3.micro, 8 GiB gp3 root volume (delete on termination), key pair <code>ewb-lab</code>. Every resource is tagged Project = EWB-VPC-Peering and Student = ${NAME}.</p>
</div>

<div class="page">
<h2>2. Network: VPCs, subnets, internet gateway, route tables</h2>
${pre('14_vpcs.txt', 'VPCs: non-overlapping CIDRs 10.10.0.0/16 and 10.20.0.0/16')}
${pre('13_subnets.txt', 'Subnets: auto-assign public IPv4 is disabled on all subnets. The bastion got its public IP at launch.')}
${pre('15_igw.txt', 'Internet gateway ewb-igw-a attached to VPC A')}
${pre('06_route_tables.txt', 'All three route tables after peering: routes and explicit subnet associations')}
<p><b>Why the public subnet needs a peering route:</b> with ProxyJump, the bastion itself opens the TCP connection to App-B, so the bastion's subnet must route 10.20.0.0/16 to the pcx. The more specific /16 route wins over the 0.0.0.0/0 default route.</p>
</div>

<div class="page">
<h2>3. Peering and security groups</h2>
${pre('04_peering_active.txt', 'Peering ewb-a-b-peer: status ACTIVE, requester VPC A, accepter VPC B')}
${pre('12_security_groups.txt', 'Inbound security group rules (outbound: default allow-all). Each source is a single /32 host.')}
<table><tr><th>Group</th><th>Rule</th><th>Source</th><th>Reason</th></tr>
<tr><td>ewb-sg-bastion</td><td>TCP 22</td><td>${ids.MYIP}/32</td><td>Only my laptop's public IP can reach the bastion</td></tr>
<tr><td>ewb-sg-app-a</td><td>TCP 22</td><td>10.10.1.10/32</td><td>SSH only from the bastion</td></tr>
<tr><td>ewb-sg-app-a</td><td>ICMP echo (8/0)</td><td>10.20.1.10/32</td><td>Reverse ping from App-B</td></tr>
<tr><td>ewb-sg-app-b</td><td>TCP 22</td><td>10.10.1.10/32</td><td>Through ProxyJump, App-B sees the bastion's private IP as the source</td></tr>
<tr><td>ewb-sg-app-b</td><td>ICMP echo (8/0)</td><td>10.10.2.10/32</td><td>Forward ping from App-A</td></tr></table>
<h3>SSH configuration used on the laptop (~/.ssh/config)</h3>
<pre>${esc(fs.readFileSync(path.join(dir, 'ssh_config'), 'utf8').replace(/\n\s+(StrictHostKeyChecking|UserKnownHostsFile).*/g, ''))}</pre>
</div>

<div class="page">
<h2>4. Verification tests</h2>
<table><tr><th>#</th><th>Test</th><th>Expected</th><th>Result</th></tr>
<tr><td>01</td><td>Baseline: App-A &#8594; 10.20.1.10 before peering</td><td>No replies</td><td class="ok">100% loss (as expected)</td></tr>
<tr><td>02</td><td>Forward: App-A &#8594; 10.20.1.10 after routes</td><td>4 replies, 0% loss</td><td class="ok">4/4, 0% loss</td></tr>
<tr><td>03</td><td>Reverse: App-B &#8594; 10.10.2.10 after routes</td><td>4 replies, 0% loss</td><td class="ok">4/4, 0% loss</td></tr>
<tr><td>04</td><td>Private SSH: laptop &#8594; ewb-app-b</td><td>Shell on App-B through bastion</td><td class="ok">Connected as ec2-user</td></tr>
<tr><td>05</td><td>Isolation: public IP on App-A / App-B</td><td>None</td><td class="ok">None on either host</td></tr>
<tr><td>06</td><td>Controlled failure: App-B ICMP rule removed / restored</td><td>Fail, then recover</td><td class="ok">100% loss &#8594; 0% loss</td></tr></table>
${pre('01_bastion_ssh.txt', 'Laptop: ssh ewb-bastion (bastion reachable)')}
${pre('02_appa_ssh_and_baseline_ping.txt', 'TEST 01 / App-A / Baseline before peering: 100% packet loss')}
${pre('03_appb_ssh_before_peering.txt', 'Extra / Laptop: ssh ewb-app-b before peering: times out (no route from bastion to VPC B)')}
${pre('05_ping_after_peering_no_routes.txt', 'Extra / App-A / Peering ACTIVE but no routes yet: still 100% loss. Active peering alone is not enough.')}
</div>

<div class="page">
<h2>4. Verification tests (continued)</h2>
${pre('07_forward_ping_appa_to_appb.txt', 'TEST 02 / App-A / Forward path ping 10.20.1.10: 4 received, 0% loss')}
${pre('08_reverse_ping_appb_to_appa.txt', 'TEST 03 / App-B (reached through the bastion) / Reverse path ping 10.10.2.10: 4 received, 0% loss')}
${pre('09_private_ssh_appb.txt', 'TEST 04 / Laptop: ssh ewb-app-b through ProxyJump: shell on App-B')}
${pre('11_instances_isolation.txt', 'TEST 05 / EC2 instance details: App-A and App-B have no public IPv4')}
</div>

<div class="page">
<h2>5. Controlled failure and recovery</h2>
${pre('10a_rule_removed.txt', 'Step 1: remove only App-B inbound ICMP Echo rule (source 10.10.2.10/32). SSH rule kept.')}
${pre('10b_ping_after_rule_removed.txt', 'Step 2 / App-A: ping 10.20.1.10: 100% packet loss')}
${pre('10c_rule_restored.txt', 'Step 3: restore the exact rule')}
${pre('10d_ping_after_rule_restored.txt', 'Step 4 / App-A: ping 10.20.1.10: 0% packet loss again')}
<p><b>Explanation:</b> routing and peering were unchanged during this test. Only the destination security group stopped permitting the ICMP echo request, so App-B silently dropped the packets. Restoring the /32 rule brought the replies back right away. This shows the routes give a path, but the security group decides whether traffic is accepted.</p>
</div>

<div class="page">
<h2>6. Forward path and return path</h2>
<p><b>Forward (App-A &#8594; App-B):</b> App-A (10.10.2.10) sends to 10.20.1.10. The ewb-rt-a-private table matches 10.20.0.0/16 &#8594; ${ids.PCX}. The packet crosses the peering connection into VPC B, and ewb-sg-app-b allows ICMP echo from 10.10.2.10/32.</p>
<p><b>Return (App-B &#8594; App-A):</b> App-B's reply goes to 10.10.2.10. The ewb-rt-b-private table matches 10.10.0.0/16 &#8594; ${ids.PCX}, so the reply goes back across the peering connection. The security group is stateful, so the reply is allowed automatically.</p>
<h3>Viva questions</h3>
<p><b>1. Why is the return route needed?</b> Routing is per subnet and one-way. Without 10.10.0.0/16 &#8594; pcx in VPC B, App-B's replies have no route back, so the connection fails even when the forward route exists.</p>
<p><b>2. Why is the App-B SSH source the bastion's private IP?</b> With ProxyJump, the bastion opens a new TCP connection to App-B from its own interface (10.10.1.10). My laptop's IP never reaches App-B.</p>
<p><b>3. Why doesn't Active peering guarantee a successful ping?</b> Peering only creates the link. Both route tables need routes to the pcx, and the destination security group must allow the traffic. Test "Peering ACTIVE but no routes yet" shows 100% loss.</p>
<p><b>4. Can VPC B use VPC A's internet gateway over peering?</b> No. VPC peering doesn't support edge-to-edge routing: traffic from VPC B can't use VPC A's IGW, NAT or VPN. Peering is also non-transitive.</p>
</div>

<div class="page">
<h2>7. Cleanup</h2>
${pre('20_cleanup.txt', 'Cleanup actions')}
${pre('21_cleanup_verify.txt', 'Verification: no project-tagged resources remain in ap-south-1')}
<h2>8. What I learned</h2>
<p style="min-height:40mm;border:1px dashed #aaa;padding:3mm">${process.env.LEARNED || '&nbsp;'}</p>
</div>
</body></html>`;
// Hide the last octet of the home IP; the /32 rule is still clear from the rest.
const masked = ids.MYIP.replace(/\.\d+$/, '.x');
fs.writeFileSync(path.join(dir, 'report.html'), html.replaceAll(ids.MYIP, masked));
console.assert(masked === ids.MYIP || !fs.readFileSync(path.join(dir, 'report.html'), 'utf8').includes(ids.MYIP), 'home IP still in report');
console.log('report.html written');
