#!/usr/bin/env bash
# EWB VPC Peering lab - baseline test, peering + routes, then all verification tests.
# Run after build.sh. Every result is saved to evidence/.
set -uo pipefail
export MSYS_NO_PATHCONV=1 AWS_REGION=ap-south-1 AWS_PAGER=""
aws() { "/c/Program Files/Amazon/AWSCLIV2/aws.exe" "$@"; }
cd "$(dirname "$0")"; source ids.env
mkdir -p evidence
STUDENT="${STUDENT:-Ayush Sharma}"
S="ssh -F ssh_config -o ConnectTimeout=15 -o LogLevel=ERROR"
run() { f=$1; shift; { echo "### HOST: $1 | $(date -u +%FT%TZ)"; echo "\$ ssh $1 '$2'"; $S "$1" "$2" 2>&1 | grep -v -e 'post-quantum' -e 'store now' -e 'pq.html'; echo "[exit ${PIPESTATUS[0]}]"; } | tee "evidence/$f"; }
# Fails loudly if a test's last line does not show the expected exit code.
expect() { tail -1 "evidence/$1" | grep -q "\[exit $2\]" || { echo "!! $1: expected exit $2"; FAILED=1; }; }
FAILED=0

# ---- Before peering ----
run 01_bastion_ssh.txt ewb-bastion 'hostname; hostname -I';                                   expect 01_bastion_ssh.txt 0
run 02_appa_ssh_and_baseline_ping.txt ewb-app-a 'hostname; hostname -I; ping -c 4 -W 2 10.20.1.10'; expect 02_appa_ssh_and_baseline_ping.txt 1
run 03_appb_ssh_before_peering.txt ewb-app-b 'hostname';                                       expect 03_appb_ssh_before_peering.txt 255

# ---- Peering ----
PCX=$(aws ec2 create-vpc-peering-connection --vpc-id $VPC_A --peer-vpc-id $VPC_B \
  --tag-specifications "ResourceType=vpc-peering-connection,Tags=[{Key=Name,Value=ewb-a-b-peer},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$STUDENT}]" \
  --query VpcPeeringConnection.VpcPeeringConnectionId --output text) || exit 1
echo "PCX=$PCX" >> ids.env
aws ec2 wait vpc-peering-connection-exists --vpc-peering-connection-ids $PCX
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PCX >/dev/null
sleep 5
aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids $PCX --query 'VpcPeeringConnections[0].{Id:VpcPeeringConnectionId,Name:Tags[?Key==`Name`]|[0].Value,Status:Status.Code,RequesterVpc:RequesterVpcInfo.VpcId,RequesterCidr:RequesterVpcInfo.CidrBlock,AccepterVpc:AccepterVpcInfo.VpcId,AccepterCidr:AccepterVpcInfo.CidrBlock}' --output table | tee evidence/04_peering_active.txt
run 05_ping_after_peering_no_routes.txt ewb-app-a 'ping -c 4 -W 2 10.20.1.10';                 expect 05_ping_after_peering_no_routes.txt 1

# ---- Routes ----
aws ec2 create-route --route-table-id $RT_A_PRIV --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id $PCX >/dev/null
aws ec2 create-route --route-table-id $RT_B_PRIV --destination-cidr-block 10.10.0.0/16 --vpc-peering-connection-id $PCX >/dev/null
aws ec2 create-route --route-table-id $RT_A_PUB --destination-cidr-block 10.20.0.0/16 --vpc-peering-connection-id $PCX >/dev/null
aws ec2 describe-route-tables --route-table-ids $RT_A_PUB $RT_A_PRIV $RT_B_PRIV --query 'RouteTables[].{Name:Tags[?Key==`Name`]|[0].Value,Id:RouteTableId,Vpc:VpcId,Subnets:join(`,`,Associations[].SubnetId),Routes:join(` | `,Routes[].join(` -> `,[DestinationCidrBlock,GatewayId||VpcPeeringConnectionId]))}' --output table | tee evidence/06_route_tables.txt
sleep 5

# ---- Verification ----
run 07_forward_ping_appa_to_appb.txt ewb-app-a 'hostname; hostname -I; ping -c 4 10.20.1.10';  expect 07_forward_ping_appa_to_appb.txt 0
run 08_reverse_ping_appb_to_appa.txt ewb-app-b 'hostname; hostname -I; ping -c 4 10.10.2.10';  expect 08_reverse_ping_appb_to_appa.txt 0
run 09_private_ssh_appb.txt ewb-app-b 'echo "Logged in to $(hostname) as $(whoami)"; hostname -I'; expect 09_private_ssh_appb.txt 0

# ---- Controlled failure ----
RULE='IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=10.10.2.10/32,Description="App-A echo request"}]'
{ echo "### Removing App-B inbound ICMP echo rule from 10.10.2.10/32 on $SG_APP_B"; aws ec2 revoke-security-group-ingress --group-id $SG_APP_B --ip-permissions "$RULE" --output json; } | tee evidence/10a_rule_removed.txt
sleep 5; run 10b_ping_after_rule_removed.txt ewb-app-a 'ping -c 4 -W 2 10.20.1.10';            expect 10b_ping_after_rule_removed.txt 1
{ echo "### Restoring the exact rule"; aws ec2 authorize-security-group-ingress --group-id $SG_APP_B --ip-permissions "$RULE" --query 'SecurityGroupRules[].{Rule:SecurityGroupRuleId,Proto:IpProtocol,Type:FromPort,Code:ToPort,Source:CidrIpv4}' --output table; } | tee evidence/10c_rule_restored.txt
sleep 5; run 10d_ping_after_rule_restored.txt ewb-app-a 'ping -c 4 10.20.1.10';                expect 10d_ping_after_rule_restored.txt 0

# ---- Inventory ----
aws ec2 describe-instances --instance-ids $I_BASTION $I_APP_A $I_APP_B --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,Id:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress||`NONE`,Subnet:SubnetId,SG:SecurityGroups[0].GroupName}' --output table | tee evidence/11_instances_isolation.txt
aws ec2 describe-security-group-rules --filters Name=group-id,Values=$SG_BASTION,$SG_APP_A,$SG_APP_B --query 'SecurityGroupRules[?IsEgress==`false`].{GroupId:GroupId,Rule:SecurityGroupRuleId,Proto:IpProtocol,FromPort_or_ICMPType:FromPort,ToPort_or_ICMPCode:ToPort,Source:CidrIpv4,Desc:Description}' --output table | tee evidence/12_security_groups.txt
aws ec2 describe-subnets --subnet-ids $SUB_A_PUB $SUB_A_PRIV $SUB_B_PRIV --query 'Subnets[].{Name:Tags[?Key==`Name`]|[0].Value,Id:SubnetId,Vpc:VpcId,Cidr:CidrBlock,AZ:AvailabilityZone,AutoPublicIP:MapPublicIpOnLaunch}' --output table | tee evidence/13_subnets.txt
aws ec2 describe-vpcs --vpc-ids $VPC_A $VPC_B --query 'Vpcs[].{Name:Tags[?Key==`Name`]|[0].Value,Id:VpcId,Cidr:CidrBlock}' --output table | tee evidence/14_vpcs.txt
aws ec2 describe-internet-gateways --internet-gateway-ids $IGW --query 'InternetGateways[].{Name:Tags[?Key==`Name`]|[0].Value,Id:InternetGatewayId,AttachedVpc:Attachments[0].VpcId,State:Attachments[0].State}' --output table | tee evidence/15_igw.txt

[ $FAILED = 0 ] && echo "ALL TESTS MATCH EXPECTED RESULTS" || { echo "SOME TESTS DID NOT MATCH - see !! lines above"; exit 1; }
