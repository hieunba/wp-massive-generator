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
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
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

  security_groups = [aws_security_group.allow_web_vpc.id]

  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
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
