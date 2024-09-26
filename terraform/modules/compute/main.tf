terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.region]
    }
  }
}


# Security Group
resource "aws_security_group" "instance" {
  provider = aws.region

  name        = "hive-gateway-instance-sg-${var.region}"
  description = "Security group for hive-gateway instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Adjust as needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template
resource "aws_launch_template" "main" {
  provider = aws.region

  name_prefix   = "hive-gateway-lt-${var.region}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance.id]

    user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    amazon-linux-extras install docker
    service docker start
    usermod -a -G docker ec2-user

    # Install AWS CLI and jq
    yum install -y awscli jq

    # Retrieve secrets from AWS Systems Manager Parameter Store
    KEYSTORE_CONTENT=$(aws ssm get-parameter --name "/hive-gateway/keystore-content" --with-decryption --query Parameter.Value --output text)
    KEYSTORE_NAME=$(aws ssm get-parameter --name "/hive-gateway/keystore-name" --query Parameter.Value --output text)
    KEYSTORE_PW=$(aws ssm get-parameter --name "/hive-gateway/keystore-pw" --with-decryption --query Parameter.Value --output text)

    # Create .lpData directory
    mkdir -p ~/.lpData

    # Write keystore file
    echo "$KEYSTORE_CONTENT" > ~/.lpData/$KEYSTORE_NAME

    # Write password file
    echo "$KEYSTORE_PW" > ~/.lpData/password.txt

    # Ensure correct permissions
    chmod 600 ~/.lpData/$KEYSTORE_NAME ~/.lpData/password.txt

    # Create a docker network named hive-gateway-network
    docker network create hive-gateway-network

    # Start the go-livepeer gateway (not exposed to internet)
    docker run -d --name livepeer \
    --network hive-gateway-network \
    -v ~/.lpData:/root/.lpData \
    livepool/go-livepool:llm \
    livepeer -gateway -mainnet -httpAddr 0.0.0.0:8935 -httpIngest -v 6 \
    -ethPassword /root/.lpData/password.txt

    # Start the openai-api server
    docker run -d --name api \
    --network hive-gateway-network \
    -p ${var.health_check_port}:${var.health_check_port} \
    livepool/openai-api:latest \
    --gateway http://livepeer:8935

    # Create nginx configuration
    cat <<'EOT' > /tmp/nginx.conf
    events {
        worker_connections 1024;
    }

    http {
        upstream api {
            server api:${var.health_check_port};
        }

        server {
            listen 80;
            server_name _;

            location / {
                proxy_pass http://api;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }
        }
    }
    EOT

    # Start nginx
    docker run -d --name nginx \
    --network hive-gateway-network \
    -p 80:80 \
    -v /tmp/nginx.conf:/etc/nginx/nginx.conf:ro \
    nginx:alpine

    # Set up a health check script
    cat <<'EOT' > /usr/local/bin/health_check.sh
    #!/bin/bash
    if ! curl -s http://localhost:${var.health_check_port}${var.health_check_path}; then
    docker restart api
    exit 1
    fi
    EOT
    chmod +x /usr/local/bin/health_check.sh

    # Set up a cron job to run the health check every 5 minutes
    echo "*/5 * * * * /usr/local/bin/health_check.sh" | crontab -

    EOF
    )

}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "hive-gateway-asg-${var.region}"
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = var.subnet_ids
  depends_on = [aws_launch_template.main]


  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
}
