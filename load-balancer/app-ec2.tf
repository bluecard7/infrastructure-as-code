resource "aws_security_group" "app_instance" {
  name        = "app_instance_rules"
  description = "Manage traffic to app instance"
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_instance" {
  count                  = 3
  ami                    = "ami-0e472933a1395e172"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.app_instance.id]
  key_name               = "test"
  user_data              = <<EOF
    sudo su
    yum update -y
    yum install -y httpd.x86_64
    systemctl start httpd.service
    systemctl enable httpd.service
    echo "Hello World from $(hostname -f)" > /var/www/html/index.html
    EOF
  tags = {
    Name = "Server ${count.index}"
  }
}