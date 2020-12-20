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
  subnets            = [aws_default_subnet.az_a.id, aws_default_subnet.az_b.id]
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

resource "aws_lb_target_group_attachment" "az_a" {
  count            = 2
  target_group_arn = aws_lb_target_group.app_instances.arn
  target_id        = aws_instance.az_a[count.index].id
}

resource "aws_lb_target_group_attachment" "az_b" {
  count            = 1
  target_group_arn = aws_lb_target_group.app_instances.arn
  target_id        = aws_instance.az_b[count.index].id
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