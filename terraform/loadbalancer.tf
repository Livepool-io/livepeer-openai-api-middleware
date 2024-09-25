# Create an Application Load Balancer in each region
resource "aws_lb" "main" {
  for_each = toset(var.regions)

  name               = "hive-gateway-alb-${each.key}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[each.key].id]
  subnets            = [for subnet in aws_subnet.main : subnet.id if split("-", subnet.availability_zone)[0] == each.key]

  enable_deletion_protection = false

  tags = {
    Name = "hive-gateway-alb-${each.key}"
  }

  provider = aws[each.key]
}

# Create a target group for each ALB
resource "aws_lb_target_group" "main" {
  for_each = toset(var.regions)

  name     = "hive-gateway-tg-${each.key}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main[each.key].id

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = var.health_check_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  provider = aws[each.key]
}

# Create an SSL certificate for each region
resource "aws_acm_certificate" "main" {
  for_each = toset(var.regions)

    domain_name       = "gateway.${var.domain_name}"
    subject_alternative_names = ["*.gateway.${var.domain_name}"]
    validation_method = "DNS"

  tags = {
    Name = "hive-gateway-cert-${each.key}"
  }

  lifecycle {
    create_before_destroy = true
  }

  provider = aws[each.key]
}

# Create a listener for each ALB (HTTPS)
resource "aws_lb_listener" "https" {
  for_each = toset(var.regions)

  load_balancer_arn = aws_lb.main[each.key].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.main[each.key].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[each.key].arn
  }

  provider = aws[each.key]
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http" {
  for_each = toset(var.regions)

  load_balancer_arn = aws_lb.main[each.key].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  provider = aws[each.key]
}

# Create a security group for the ALB
resource "aws_security_group" "alb" {
  for_each = toset(var.regions)

  name        = "hive-gateway-alb-sg-${each.key}"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main[each.key].id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere (for redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  provider = aws[each.key]
}

# Validate the certificates
resource "aws_acm_certificate_validation" "main" {
  for_each = toset(var.regions)

  certificate_arn         = aws_acm_certificate.main[each.key].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation[each.key] : record.fqdn]

  provider = aws[each.key]
}