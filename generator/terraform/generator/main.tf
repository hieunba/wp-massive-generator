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
