terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  azs = toset(["us-west-2a", "us-west-2b", "us-west-2c"])
}

resource "aws_default_vpc" "default" {
}

resource "aws_default_subnet" "az" {
  for_each          = local.azs
  availability_zone = each.key
}

resource "aws_security_group" "alb" {
  name        = "load_balancer_rules"
  description = "Manage traffic to app load balancer"
  ingress {
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
}

resource "aws_lb" "alb" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for k in local.azs : aws_default_subnet.az[k].id]
}

resource "aws_security_group" "app_instance" {
  name        = "app_instance_rules"
  description = "Manage traffic to app instance"
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "app_instances" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default.id

  health_check {
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_instances.arn
  }
}


resource "aws_launch_template" "asg" {
  name_prefix            = "acg"
  image_id               = "ami-0e472933a1395e172"
  instance_type          = "t2.micro"
  key_name               = "test"
  vpc_security_group_ids = [aws_security_group.app_instance.id]
  user_data = base64encode(
    <<EOF
    #!/bin/sh
    yum update -y
    yum install -y httpd.x86_64
    systemctl start httpd.service
    systemctl enable httpd.service
    echo "Hello World from $(hostname -f)" > /var/www/html/index.html
    EOF 
  )
}

resource "aws_autoscaling_group" "asg" {
  availability_zones        = local.azs
  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 3
  default_cooldown          = 60
  health_check_type         = "ELB"
  health_check_grace_period = 60

  target_group_arns = [aws_lb_target_group.app_instances.arn]

  launch_template {
    id      = aws_launch_template.asg.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "asg" {
  name                   = "release-instance"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "asg" {
  alarm_name          = "TooMuchCPUReady"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "30"
  statistic           = "Average"
  threshold           = "50"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.asg.arn]
}
