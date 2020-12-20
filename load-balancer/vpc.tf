resource "aws_default_vpc" "default" {
}

resource "aws_default_subnet" "az_a" {
  availability_zone = "us-west-2a"
}

resource "aws_default_subnet" "az_b" {
  availability_zone = "us-west-2b"
}