# Create a security group for our instances in each region
resource "aws_security_group" "instance" {
  for_each = toset(var.regions)

  name        = "hive-gateway-instance-sg-${each.key}"
  description = "Security group for hive-gateway instances"
  vpc_id      = aws_vpc.main[each.key].id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Health check"
    from_port   = var.health_check_port
    to_port     = var.health_check_port
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main[each.key].cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  provider = aws[each.key]
}

# Create a launch template for our instances in each region
resource "aws_launch_template" "main" {
  for_each = toset(var.regions)

  name_prefix   = "hive-gateway-lt-${each.key}-"
  image_id      = var.amis[each.key]
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance[each.key].id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              amazon-linux-extras install docker
              service docker start
              usermod -a -G docker ec2-user
              docker run -d --name livepeer livepeer/go-livepeer:latest livepeer -network mainnet -gateway
              docker run -d --name api -p ${var.health_check_port}:${var.health_check_port} your-dockerhub-username/api-service:latest
              docker run -d --name nginx -p 80:80 -v /path/to/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine

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

  provider = aws[each.key]
}

# Create an Auto Scaling Group in each region
resource "aws_autoscaling_group" "main" {
  for_each = toset(var.regions)

  name                = "hive-gateway-asg-${each.key}"
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
  min_size            = var.asg_min_size
  target_group_arns   = [aws_lb_target_group.main[each.key].arn]
  vpc_zone_identifier = [for subnet in aws_subnet.main : subnet.id if split("-", subnet.availability_zone)[0] == each.key]

  launch_template {
    id      = aws_launch_template.main[each.key].id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  provider = aws[each.key]
}