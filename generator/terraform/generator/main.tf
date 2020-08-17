provider "aws" {
  region = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name   = "wp-vpc"
  cidr   = var.cidr_block

  azs             = var.azs[trimspace(var.region)]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  tags = {
    Generator = "true"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "allow_web_alb" {
  name        = "allow_web_alb"
  description = "Allow web inbound traffic to Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = 6
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_web_vpc" {
  name        = "allow_web_vpc"
  description = "Allow web inbound traffic from Load Balancer to EC2 instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = 6
    security_groups = [aws_security_group.allow_web_alb.id]
    self            = true
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = 6
    security_groups = [aws_security_group.allow_web_alb.id]
    self            = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_db_vpc" {
  name        = "allow_db_vpc"
  description = "Allow MySQL inbound traffic between VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = 6
    security_groups = [aws_security_group.allow_web_vpc.id]
    self            = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "wp-http" {
  name               = "wp-http"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_alb.id]
  subnets            = module.vpc.public_subnets

  tags = {
    Name = "wp-stack"
  }
}

resource "aws_lb_target_group" "wp-http" {
  name                               = "wp-http"
  port                               = 80
  protocol                           = "HTTP"
  vpc_id                             = module.vpc.vpc_id
  lambda_multi_value_headers_enabled = false
  proxy_protocol_v2                  = false

  health_check {
    path                = "/"
    matcher             = "200,301,302"
    healthy_threshold   = 5
    unhealthy_threshold = 5
    timeout             = 6
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 3600
    enabled         = true
  }
}

resource "aws_lb_listener" "wp-http" {
  load_balancer_arn = aws_lb.wp-http.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp-http.arn
  }
}

resource "aws_placement_group" "wp" {
  name     = "wp"
  strategy = "spread"
}

resource "aws_launch_configuration" "wp" {
  name_prefix   = var.prefix
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name == "" ? var.default_key_name : var.key_name

  security_groups = [aws_security_group.allow_web_vpc.id, aws_security_group.allow_ssh.id]

  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }

  user_data = file("scripts/bootstrap/provisioner.sh")
}

resource "aws_autoscaling_group" "wp" {
  name_prefix               = var.prefix
  max_size                  = var.autoscale_max_size
  min_size                  = var.autoscale_min_size

  health_check_grace_period = 300
  health_check_type         = "ELB"

  placement_group           = aws_placement_group.wp.id

  launch_configuration      = aws_launch_configuration.wp.name

  vpc_zone_identifier       = module.vpc.public_subnets
  target_group_arns         = [aws_lb_target_group.wp-http.arn]

  force_delete              = false
  termination_policies      = ["OldestInstance"]

  wait_for_capacity_timeout = "10m"
}

resource "aws_autoscaling_policy" "wp" {
  name                      = "wp"
  autoscaling_group_name    = aws_autoscaling_group.wp.name

  estimated_instance_warmup = 60

  policy_type               = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60
  }
}

resource "aws_db_instance" "wp" {
  identifier_prefix       = var.prefix
  name                    = "wordpress"
  storage_type            = "gp2"
  allocated_storage       = 50
  max_allocated_storage   = 100
  engine                  = "mysql"
  engine_version          = "5.7"
  instance_class          = var.db_instance_class
  username                = var.default_username
  password                = var.default_password
  publicly_accessible     = var.db_publicly_accessible
  skip_final_snapshot     = var.db_skip_final_snapshot
  parameter_group_name    = aws_db_parameter_group.wp.name
  backup_retention_period = 7

  db_subnet_group_name    = aws_db_subnet_group.wp.id
  vpc_security_group_ids  = [aws_security_group.allow_db_vpc.id]

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  apply_immediately = true
}

resource "aws_db_subnet_group" "wp" {
  name_prefix   = var.prefix
  subnet_ids = module.vpc.public_subnets
}

resource "aws_db_parameter_group" "wp" {
  name_prefix   = var.prefix
  family = "mysql5.7"

  parameter {
    name = "max_allowed_packet"
    value = 268435456
  }

  parameter {
    name = "slow_query_log"
    value = 1
  }
}

resource "aws_cloudfront_distribution" "wp_distribution" {
  origin {
    domain_name = aws_lb.wp-http.dns_name
    origin_id   = "wp-application"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.php"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "wp-application"

    forwarded_values {
      query_string = false

      cookies {
        forward           = "whitelist"
        whitelisted_names = [
          "comment_author_*",
          "comment_author_email_*",
          "comment_author_url_*",
          "wordpress_logged_in_*",
          "wordpress_test_cookie",
          "wp-settings-*"
        ]
      }
    }


    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "VN"]
    }
  }

  tags = {
    Name = "WP"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [aws_lb.wp-http]
}
