#!/usr/bin/env bash
# EWB VPC Peering lab - remove every resource created for the project.
set -uo pipefail
export MSYS_NO_PATHCONV=1 AWS_REGION=ap-south-1 AWS_PAGER=""
aws() { "/c/Program Files/Amazon/AWSCLIV2/aws.exe" "$@"; }
cd "$(dirname "$0")"; source ids.env
step() { echo; echo "### $(date -u +%T)Z  $*"; }

step "Terminate instances: $I_BASTION $I_APP_A $I_APP_B"
aws ec2 terminate-instances --instance-ids $I_BASTION $I_APP_A $I_APP_B --query 'TerminatingInstances[].[InstanceId,CurrentState.Name]' --output text
aws ec2 wait instance-terminated --instance-ids $I_BASTION $I_APP_A $I_APP_B && echo "All three instances terminated"
step "Delete key pair ewb-lab"
aws ec2 delete-key-pair --key-name ewb-lab --query Return --output text

step "Delete peer routes"
aws ec2 delete-route --route-table-id $RT_A_PRIV --destination-cidr-block 10.20.0.0/16 && echo "ewb-rt-a-private 10.20.0.0/16 removed"
aws ec2 delete-route --route-table-id $RT_B_PRIV --destination-cidr-block 10.10.0.0/16 && echo "ewb-rt-b-private 10.10.0.0/16 removed"
aws ec2 delete-route --route-table-id $RT_A_PUB --destination-cidr-block 10.20.0.0/16 && echo "ewb-rt-a-public 10.20.0.0/16 removed"
step "Delete peering $PCX"
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PCX --query Return --output text

step "Delete security groups"
for sg in $SG_APP_A $SG_APP_B $SG_BASTION; do aws ec2 delete-security-group --group-id $sg --query GroupId --output text; done

step "Delete subnets"
for s in $SUB_A_PUB $SUB_A_PRIV $SUB_B_PRIV; do aws ec2 delete-subnet --subnet-id $s && echo "$s deleted"; done
step "Delete custom route tables"
for r in $RT_A_PUB $RT_A_PRIV $RT_B_PRIV; do aws ec2 delete-route-table --route-table-id $r && echo "$r deleted"; done
step "Detach and delete internet gateway $IGW"
aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_A && aws ec2 delete-internet-gateway --internet-gateway-id $IGW && echo "$IGW deleted"
step "Delete VPCs"
for v in $VPC_A $VPC_B; do aws ec2 delete-vpc --vpc-id $v && echo "$v deleted"; done
# Archive ids.env only once both VPCs are gone; build.sh refuses to run while it exists.
if aws ec2 describe-vpcs --vpc-ids $VPC_A $VPC_B >/dev/null 2>&1; then echo "VPCs still exist: ids.env kept, fix errors and rerun cleanup.sh"; exit 1; fi
mv ids.env evidence/00_resource_ids.txt && echo "ids.env archived to evidence/00_resource_ids.txt"

# Final check: nothing tagged for this project should be left (all counts 0).
F="Name=tag:Project,Values=EWB-VPC-Peering"
{
echo "### $(date -u +%FT%TZ)  Region $AWS_REGION, filter tag Project=EWB-VPC-Peering"
echo "Instances (not terminated): $(aws ec2 describe-instances --filters $F Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down --query 'length(Reservations[].Instances[])')"
echo "EBS volumes:                $(aws ec2 describe-volumes --filters $F --query 'length(Volumes)')"
echo "Elastic IPs (any):          $(aws ec2 describe-addresses --query 'length(Addresses)')"
echo "Key pair ewb-lab:           $(aws ec2 describe-key-pairs --filters Name=key-name,Values=ewb-lab --query 'length(KeyPairs)')"
echo "VPCs:                       $(aws ec2 describe-vpcs --filters $F --query 'length(Vpcs)')"
echo "Subnets:                    $(aws ec2 describe-subnets --filters $F --query 'length(Subnets)')"
echo "Route tables:               $(aws ec2 describe-route-tables --filters $F --query 'length(RouteTables)')"
echo "Internet gateways:          $(aws ec2 describe-internet-gateways --filters $F --query 'length(InternetGateways)')"
echo "Security groups:            $(aws ec2 describe-security-groups --filters $F --query 'length(SecurityGroups)')"
echo "Peering (active/pending):   $(aws ec2 describe-vpc-peering-connections --filters $F Name=status-code,Values=active,pending-acceptance,provisioning --query 'length(VpcPeeringConnections)')"
} | tee evidence/21_cleanup_verify.txt
rm -f ~/.ssh/ewb-lab.pem ~/.ssh/ewb_known_hosts && echo "local lab key removed"
