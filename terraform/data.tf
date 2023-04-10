data "aws_availability_zones" "availability" {}

data "aws_ami" "latest_ubuntu" {
    owners = ["amazon"]
    most_recent = true
    filter {
      name = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }
}