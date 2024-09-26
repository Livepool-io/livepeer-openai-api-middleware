#!/bin/bash

# List of AWS regions to process
regions=("us-east-1" "us-west-2" "eu-central-1" "ap-northeast-1")

# Loop through each region
for region in "${regions[@]}"; do
  echo "Processing region: $region"

  # Set AWS region for AWS CLI commands
  export AWS_DEFAULT_REGION=$region

  #######################
  # Delete EC2 Instances
  #######################
  echo "Terminating EC2 instances in $region..."
  instance_ids=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" --output text)
  if [ -n "$instance_ids" ]; then
    aws ec2 terminate-instances --instance-ids $instance_ids
    aws ec2 wait instance-terminated --instance-ids $instance_ids
    echo "Terminated instances: $instance_ids"
  else
    echo "No instances to terminate in $region."
  fi

  ##############################
  # Delete Auto Scaling Groups
  ##############################
  echo "Deleting Auto Scaling Groups in $region..."
  asg_names=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[*].AutoScalingGroupName" --output text)
  if [ -n "$asg_names" ]; then
    for asg in $asg_names; do
      aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg --min-size 0 --max-size 0 --desired-capacity 0
      aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asg --force-delete
      echo "Deleted Auto Scaling Group: $asg"
    done
  else
    echo "No Auto Scaling Groups to delete in $region."
  fi

  ##########################
  # Delete Load Balancers
  ##########################
  echo "Deleting Load Balancers in $region..."
  lb_arns=$(aws elbv2 describe-load-balancers --query "LoadBalancers[*].LoadBalancerArn" --output text)
  if [ -n "$lb_arns" ]; then
    for lb_arn in $lb_arns; do
      aws elbv2 delete-load-balancer --load-balancer-arn $lb_arn
      echo "Deleted Load Balancer: $lb_arn"
    done
  else
    echo "No Load Balancers to delete in $region."
  fi

  ##############################
  # Delete Target Groups
  ##############################
  echo "Deleting Target Groups in $region..."
  tg_arns=$(aws elbv2 describe-target-groups --query "TargetGroups[*].TargetGroupArn" --output text)
  if [ -n "$tg_arns" ]; then
    for tg_arn in $tg_arns; do
      aws elbv2 delete-target-group --target-group-arn $tg_arn
      echo "Deleted Target Group: $tg_arn"
    done
  else
    echo "No Target Groups to delete in $region."
  fi

  #########################
  # Delete Security Groups
  #########################
  echo "Deleting Security Groups in $region..."
  sg_ids=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
  if [ -n "$sg_ids" ]; then
    for sg_id in $sg_ids; do
      aws ec2 delete-security-group --group-id $sg_id
      echo "Deleted Security Group: $sg_id"
    done
  else
    echo "No Security Groups to delete in $region."
  fi

  #######################
  # Delete EC2 Key Pairs
  #######################
  echo "Deleting Key Pairs in $region..."
  key_names=$(aws ec2 describe-key-pairs --query "KeyPairs[*].KeyName" --output text)
  if [ -n "$key_names" ]; then
    for key_name in $key_names; do
      aws ec2 delete-key-pair --key-name "$key_name"
      echo "Deleted Key Pair: $key_name"
    done
  else
    echo "No Key Pairs to delete in $region."
  fi

  #######################
  # Delete Elastic IPs
  #######################
  echo "Releasing Elastic IPs in $region..."
  allocation_ids=$(aws ec2 describe-addresses --query "Addresses[*].AllocationId" --output text)
  if [ -n "$allocation_ids" ]; then
    for allocation_id in $allocation_ids; do
      aws ec2 release-address --allocation-id $allocation_id
      echo "Released Elastic IP: $allocation_id"
    done
  else
    echo "No Elastic IPs to release in $region."
  fi

  #############################
  # Delete NAT Gateways
  #############################
  echo "Deleting NAT Gateways in $region..."
  nat_gateway_ids=$(aws ec2 describe-nat-gateways --query "NatGateways[*].NatGatewayId" --output text)
  if [ -n "$nat_gateway_ids" ]; then
    for nat_gateway_id in $nat_gateway_ids; do
      aws ec2 delete-nat-gateway --nat-gateway-id $nat_gateway_id
      echo "Deleted NAT Gateway: $nat_gateway_id"
    done
  else
    echo "No NAT Gateways to delete in $region."
  fi

  #########################
  # Detach and Delete IGWs
  #########################
  echo "Deleting Internet Gateways in $region..."
  igw_ids=$(aws ec2 describe-internet-gateways --query "InternetGateways[*].InternetGatewayId" --output text)
  if [ -n "$igw_ids" ]; then
    for igw_id in $igw_ids; do
      vpc_id=$(aws ec2 describe-internet-gateways --internet-gateway-ids $igw_id --query "InternetGateways[0].Attachments[0].VpcId" --output text)
      if [ "$vpc_id" != "None" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id
      fi
      aws ec2 delete-internet-gateway --internet-gateway-id $igw_id
      echo "Deleted Internet Gateway: $igw_id"
    done
  else
    echo "No Internet Gateways to delete in $region."
  fi

  ########################
  # Delete Route Tables
  ########################
  echo "Deleting Route Tables in $region..."
  route_table_ids=$(aws ec2 describe-route-tables --query "RouteTables[?Associations[0].Main==\`false\`].RouteTableId" --output text)
  if [ -n "$route_table_ids" ]; then
    for rt_id in $route_table_ids; do
      aws ec2 delete-route-table --route-table-id $rt_id
      echo "Deleted Route Table: $rt_id"
    done
  else
    echo "No Route Tables to delete in $region."
  fi

  #####################
  # Delete Subnets
  #####################
  echo "Deleting Subnets in $region..."
  subnet_ids=$(aws ec2 describe-subnets --query "Subnets[*].SubnetId" --output text)
  if [ -n "$subnet_ids" ]; then
    for subnet_id in $subnet_ids; do
      aws ec2 delete-subnet --subnet-id $subnet_id
      echo "Deleted Subnet: $subnet_id"
    done
  else
    echo "No Subnets to delete in $region."
  fi

  #####################
  # Delete VPCs
  #####################
  echo "Deleting VPCs in $region..."
  vpc_ids=$(aws ec2 describe-vpcs --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text)
  if [ -n "$vpc_ids" ]; then
    for vpc_id in $vpc_ids; do
      aws ec2 delete-vpc --vpc-id $vpc_id
      echo "Deleted VPC: $vpc_id"
    done
  else
    echo "No VPCs to delete in $region."
  fi

  ###########################
  # Delete Elastic Load Balancers (Classic)
  ###########################
  echo "Deleting Classic Load Balancers in $region..."
  elb_names=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[*].LoadBalancerName" --output text)
  if [ -n "$elb_names" ]; then
    for elb_name in $elb_names; do
      aws elb delete-load-balancer --load-balancer-name $elb_name
      echo "Deleted Classic Load Balancer: $elb_name"
    done
  else
    echo "No Classic Load Balancers to delete in $region."
  fi

  #############################
  # Delete Launch Configurations
  #############################
  echo "Deleting Launch Configurations in $region..."
  lc_names=$(aws autoscaling describe-launch-configurations --query "LaunchConfigurations[*].LaunchConfigurationName" --output text)
  if [ -n "$lc_names" ]; then
    for lc_name in $lc_names; do
      aws autoscaling delete-launch-configuration --launch-configuration-name $lc_name
      echo "Deleted Launch Configuration: $lc_name"
    done
  else
    echo "No Launch Configurations to delete in $region."
  fi

  ##########################
  # Delete RDS Instances
  ##########################
  echo "Deleting RDS Instances in $region..."
  db_instance_identifiers=$(aws rds describe-db-instances --query "DBInstances[*].DBInstanceIdentifier" --output text)
  if [ -n "$db_instance_identifiers" ]; then
    for db_instance_id in $db_instance_identifiers; do
      aws rds delete-db-instance --db-instance-identifier $db_instance_id --skip-final-snapshot
      echo "Deleted RDS Instance: $db_instance_id"
    done
  else
    echo "No RDS Instances to delete in $region."
  fi

  ##########################
  # Delete S3 Buckets
  ##########################
  echo "Deleting S3 Buckets in $region..."
  buckets=$(aws s3api list-buckets --query "Buckets[*].Name" --output text)
  if [ -n "$buckets" ]; then
    for bucket in $buckets; do
      # Check bucket region
      bucket_region=$(aws s3api get-bucket-location --bucket $bucket --output text)
      if [ "$bucket_region" == "None" ]; then
        bucket_region="us-east-1"
      fi
      if [ "$bucket_region" == "$region" ]; then
        # Empty and delete bucket
        aws s3 rb "s3://$bucket" --force
        echo "Deleted S3 Bucket: $bucket"
      fi
    done
  else
    echo "No S3 Buckets to delete in $region."
  fi

  ###########################
  # Delete CloudFormation Stacks
  ###########################
  echo "Deleting CloudFormation Stacks in $region..."
  stack_names=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[*].StackName" --output text)
  if [ -n "$stack_names" ]; then
    for stack_name in $stack_names; do
      aws cloudformation delete-stack --stack-name $stack_name
      echo "Deleted CloudFormation Stack: $stack_name"
    done
  else
    echo "No CloudFormation Stacks to delete in $region."
  fi

  echo "Finished processing region: $region"
  echo "--------------------------------------------"

done

echo "All specified regions have been processed."
