#!/usr/bin/env bash
# EWB VPC Peering lab - build network, security groups and instances (pre-peering).
set -euo pipefail
export MSYS_NO_PATHCONV=1 AWS_REGION=ap-south-1 AWS_PAGER=""
aws() { "/c/Program Files/Amazon/AWSCLIV2/aws.exe" "$@"; }
cd "$(dirname "$0")"
mkdir -p evidence
STUDENT="${STUDENT:-Ayush Sharma}"
AZ=ap-south-1a
IDS=ids.env
# A non-empty ids.env means an earlier build's resources still exist; overwriting it would orphan them.
[ -s "$IDS" ] && { echo "ids.env is not empty: run cleanup.sh first"; exit 1; }
save() { echo "$1=$2" >> "$IDS"; echo "$1=$2"; }
tags() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Project,Value=EWB-VPC-Peering},{Key=Student,Value=$STUDENT}]"; }

# ---- VPC A ----
VPC_A=$(aws ec2 create-vpc --cidr-block 10.10.0.0/16 --tag-specifications "$(tags vpc ewb-vpc-a)" --query Vpc.VpcId --output text); save VPC_A $VPC_A
SUB_A_PUB=$(aws ec2 create-subnet --vpc-id $VPC_A --cidr-block 10.10.1.0/24 --availability-zone $AZ --tag-specifications "$(tags subnet ewb-a-public)" --query Subnet.SubnetId --output text); save SUB_A_PUB $SUB_A_PUB
SUB_A_PRIV=$(aws ec2 create-subnet --vpc-id $VPC_A --cidr-block 10.10.2.0/24 --availability-zone $AZ --tag-specifications "$(tags subnet ewb-a-private)" --query Subnet.SubnetId --output text); save SUB_A_PRIV $SUB_A_PRIV
IGW=$(aws ec2 create-internet-gateway --tag-specifications "$(tags internet-gateway ewb-igw-a)" --query InternetGateway.InternetGatewayId --output text); save IGW $IGW
aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_A
RT_A_PUB=$(aws ec2 create-route-table --vpc-id $VPC_A --tag-specifications "$(tags route-table ewb-rt-a-public)" --query RouteTable.RouteTableId --output text); save RT_A_PUB $RT_A_PUB
aws ec2 associate-route-table --route-table-id $RT_A_PUB --subnet-id $SUB_A_PUB >/dev/null
aws ec2 create-route --route-table-id $RT_A_PUB --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW >/dev/null
RT_A_PRIV=$(aws ec2 create-route-table --vpc-id $VPC_A --tag-specifications "$(tags route-table ewb-rt-a-private)" --query RouteTable.RouteTableId --output text); save RT_A_PRIV $RT_A_PRIV
aws ec2 associate-route-table --route-table-id $RT_A_PRIV --subnet-id $SUB_A_PRIV >/dev/null

# ---- VPC B ----
VPC_B=$(aws ec2 create-vpc --cidr-block 10.20.0.0/16 --tag-specifications "$(tags vpc ewb-vpc-b)" --query Vpc.VpcId --output text); save VPC_B $VPC_B
SUB_B_PRIV=$(aws ec2 create-subnet --vpc-id $VPC_B --cidr-block 10.20.1.0/24 --availability-zone $AZ --tag-specifications "$(tags subnet ewb-b-private)" --query Subnet.SubnetId --output text); save SUB_B_PRIV $SUB_B_PRIV
RT_B_PRIV=$(aws ec2 create-route-table --vpc-id $VPC_B --tag-specifications "$(tags route-table ewb-rt-b-private)" --query RouteTable.RouteTableId --output text); save RT_B_PRIV $RT_B_PRIV
aws ec2 associate-route-table --route-table-id $RT_B_PRIV --subnet-id $SUB_B_PRIV >/dev/null

# ---- Security groups ----
MYIP=$(curl -s https://checkip.amazonaws.com | tr -d '\r\n')
[[ $MYIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Could not detect public IPv4 (got '$MYIP')"; exit 1; }
save MYIP $MYIP
SG_BASTION=$(aws ec2 create-security-group --vpc-id $VPC_A --group-name ewb-sg-bastion --description "EWB bastion SSH from student IP" --tag-specifications "$(tags security-group ewb-sg-bastion)" --query GroupId --output text); save SG_BASTION $SG_BASTION
SG_APP_A=$(aws ec2 create-security-group --vpc-id $VPC_A --group-name ewb-sg-app-a --description "EWB App-A" --tag-specifications "$(tags security-group ewb-sg-app-a)" --query GroupId --output text); save SG_APP_A $SG_APP_A
SG_APP_B=$(aws ec2 create-security-group --vpc-id $VPC_B --group-name ewb-sg-app-b --description "EWB App-B" --tag-specifications "$(tags security-group ewb-sg-app-b)" --query GroupId --output text); save SG_APP_B $SG_APP_B
ssh_rule() { echo "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$1,Description=\"$2\"}]"; }
icmp_rule() { echo "IpProtocol=icmp,FromPort=8,ToPort=0,IpRanges=[{CidrIp=$1,Description=\"$2\"}]"; }
aws ec2 authorize-security-group-ingress --group-id $SG_BASTION --ip-permissions "$(ssh_rule $MYIP/32 'Student laptop')" >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_APP_A --ip-permissions "$(ssh_rule 10.10.1.10/32 'Bastion private IP')" "$(icmp_rule 10.20.1.10/32 'App-B echo request')" >/dev/null
aws ec2 authorize-security-group-ingress --group-id $SG_APP_B --ip-permissions "$(ssh_rule 10.10.1.10/32 'Bastion private IP')" "$(icmp_rule 10.10.2.10/32 'App-A echo request')" >/dev/null

# ---- Key pair (stored only on this laptop) ----
mkdir -p ~/.ssh
if [ ! -f ~/.ssh/ewb-lab.pem ]; then
  # Write to a temp file so a failed call never leaves an empty key that later runs would reuse.
  aws ec2 create-key-pair --key-name ewb-lab --key-type rsa --tag-specifications "$(tags key-pair ewb-lab)" --query KeyMaterial --output text > ~/.ssh/ewb-lab.pem.tmp \
    || { rm -f ~/.ssh/ewb-lab.pem.tmp; exit 1; }
  mv ~/.ssh/ewb-lab.pem.tmp ~/.ssh/ewb-lab.pem
  chmod 400 ~/.ssh/ewb-lab.pem
fi

# ---- Instances ----
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text); save AMI $AMI
launch() { # name subnet ip sg publicip(true|false)
  aws ec2 run-instances --image-id $AMI --instance-type t3.micro --key-name ewb-lab \
    --network-interfaces "DeviceIndex=0,SubnetId=$2,PrivateIpAddress=$3,Groups=$4,AssociatePublicIpAddress=$5,DeleteOnTermination=true" \
    --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=8,VolumeType=gp3,DeleteOnTermination=true}' \
    --metadata-options HttpTokens=required \
    --tag-specifications "$(tags instance $1)" "$(tags volume $1-root)" \
    --query 'Instances[0].InstanceId' --output text
}
I_BASTION=$(launch ewb-bastion $SUB_A_PUB 10.10.1.10 $SG_BASTION true); save I_BASTION $I_BASTION
I_APP_A=$(launch ewb-app-a $SUB_A_PRIV 10.10.2.10 $SG_APP_A false); save I_APP_A $I_APP_A
I_APP_B=$(launch ewb-app-b $SUB_B_PRIV 10.20.1.10 $SG_APP_B false); save I_APP_B $I_APP_B
echo "Waiting for instances to pass status checks..."
aws ec2 wait instance-status-ok --instance-ids $I_BASTION $I_APP_A $I_APP_B
BASTION_IP=$(aws ec2 describe-instances --instance-ids $I_BASTION --query 'Reservations[0].Instances[0].PublicIpAddress' --output text); save BASTION_IP $BASTION_IP

cat > ssh_config <<EOF
Host ewb-bastion
    HostName $BASTION_IP
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/ewb_known_hosts

Host ewb-app-a
    HostName 10.10.2.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/ewb_known_hosts

Host ewb-app-b
    HostName 10.20.1.10
    User ec2-user
    IdentityFile ~/.ssh/ewb-lab.pem
    IdentitiesOnly yes
    ProxyJump ewb-bastion
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/ewb_known_hosts
EOF
echo "BUILD COMPLETE"
