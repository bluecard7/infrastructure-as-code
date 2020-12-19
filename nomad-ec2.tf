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

resource "aws_security_group" "nomad" {
  name        = "nomad_traffic_rules"
  description = "Manage traffic to EC2 instance running Nomad Scheduler"
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

resource "aws_instance" "nomad" {
  ami             = "ami-0e472933a1395e172"
  instance_type   = "t2.micro"
  vpc_security_group_ids = [aws_security_group.nomad.id]
  key_name        = "nomad"
  user_data       = <<EOF
#!/bin/sh
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install nomad
EOF
}

