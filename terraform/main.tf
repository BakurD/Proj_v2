provider "aws" {}

#Create VPC with enable dns hostname, to read ip adress with the help of ansible dynamic inventory
resource "aws_vpc" "Mega" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    "Name" = "Mega IAC VPC"
  }
}
#IGW
resource "aws_internet_gateway" "Mega_gateway" {
  vpc_id = aws_vpc.Mega.id
  tags = {
    "Name" = "Mega IGW"
  }
}
#ASG
resource "aws_security_group" "HTTP_HTTPS_SSH" {
  vpc_id = aws_vpc.Mega.id
  name = "Mega secure group"
  dynamic "ingress" {
    for_each = [ "80", "443", "22", "3000", "9090", "9100" ]
    content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress  {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  tags = {
    "Name"  = "Dynamic Security Group"
    "Owner" = "Bakurevych Maxim" 
}  
}
#Create Public Subnet, him route table and associate them
resource "aws_subnet" "Public_Subnet" {
  vpc_id = aws_vpc.Mega.id
  cidr_block = element(var.public_subnet_cidr, count.index)
  availability_zone = data.aws_availability_zones.availability.names[count.index]
  map_public_ip_on_launch = true
  count = length(var.public_subnet_cidr)
  tags = {
    "Name" = "Public Subnet"
  }
}

resource "aws_route_table" "public_subnet_route_table" {
  vpc_id = aws_vpc.Mega.id
  route  {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Mega_gateway.id
  }
  tags = {
    Name = "Route table for public Subnet"
  } 
}

resource "aws_route_table_association" "public_associations" {
  count = length(aws_subnet.Public_Subnet[*].id)
  route_table_id = aws_route_table.public_subnet_route_table.id
  subnet_id = element(aws_subnet.Public_Subnet[*].id, count.index)
}

#Create Private Subnet, him route table and associate them
#Create EIP for NAT, Create NAT, and allocate them of public subnet

resource "aws_subnet" "Private_Subnet" {
    vpc_id = aws_vpc.Mega.id
    cidr_block = var.private_subnet_cidr
    availability_zone = data.aws_availability_zones.availability.names[0]
    map_public_ip_on_launch = false
    tags = {
        Name = "Private Subnet"
    }
}

resource "aws_route_table" "private_subnet_route_table" {
  vpc_id = aws_vpc.Mega.id
  tags = {
    "Name" = "Route table for private Subnet"
  }
}

resource "aws_route_table_association" "private_associations" {
  route_table_id = aws_route_table.private_subnet_route_table.id
  subnet_id = aws_subnet.Private_Subnet.id
}

resource "aws_eip" "NAT" {
  vpc = true
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.NAT.id
  subnet_id = aws_subnet.Public_Subnet[0].id
  tags = {
    "Name" = "NAT"
  }
}

resource "aws_route" "private_nat" {
  route_table_id = aws_route_table.private_subnet_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route" "public_nat" {
  route_table_id = aws_route_table.public_subnet_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.Mega_gateway.id
}

#Create LC, ELB, ASG, and one another instance with OpenVPN Setup in Public Subnet
resource "aws_launch_configuration" "web" {
  name_prefix = "Web-Servers-Hught_available"
  associate_public_ip_address = true
  key_name = "CI_CD"
  image_id = data.aws_ami.latest_ubuntu.id
  iam_instance_profile = "EC2_Code_Deploy"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.HTTP_HTTPS_SSH.id]
  user_data = <<EOF
#!/bin/bash
sudo apt update -y
sudo apt install apache2 -y
echo "<html><body bgcolor=white><center><h2><p><front color=red>Bootstraping one love</h2></center></html>" > /var/www/html/index.html
sudo service apache2 start
chkconfig apache2 on
echo "UserData excuted on $(date)" >> /var/www/html/log.txt
sudo apt install ruby-full -y
sudo apt install wget -y
cd /home/ubuntu
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
sudo chmod +x ./install
sudo ./install auto
sudo yum install -y python3-pip
sudo pip install awscli
echo "-----FINISH-----"
EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size = 3
  max_size = 3
  min_elb_capacity = 3
  vpc_zone_identifier = [element(aws_subnet.Public_Subnet.*.id, 1), element(aws_subnet.Public_Subnet.*.id, 0)]
  health_check_type = "ELB"
  health_check_grace_period = 300
  target_group_arns = ["${aws_lb_target_group.target_balancer.arn}"]
  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      Owner  = "Maxim Bakurevych"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_launch_configuration.web
  ]
}

resource "aws_lb_target_group" "target_balancer" {
  name_prefix = "tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.Mega.id
}

resource "aws_lb_listener" "listener_balancer" {
  load_balancer_arn = "${aws_lb.balance.arn}"
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = "${aws_lb_target_group.target_balancer.arn}"
  }
}

resource "aws_lb" "balance" {
  name = "elb"
  internal = false
  security_groups = [aws_security_group.HTTP_HTTPS_SSH.id]
  subnets = [element(aws_subnet.Public_Subnet.*.id, 1), element(aws_subnet.Public_Subnet.*.id, 0)]
}

#Create one instance in private subnet

resource "aws_network_interface" "private_network_interface" {
  subnet_id = aws_subnet.Private_Subnet.id
  security_groups = [aws_security_group.HTTP_HTTPS_SSH.id]
  depends_on = [
    aws_subnet.Private_Subnet
  ]
}

resource "aws_instance" "private_instance" {
  ami = data.aws_ami.latest_ubuntu.id
  key_name = "CI_CD"
  instance_type = "t2.micro"
  network_interface {
    network_interface_id = aws_network_interface.private_network_interface.id
    device_index         = 0
  }
  tags = {
    "Name" = "Instance in Private Subnet"
  }
  depends_on = [
    aws_network_interface.private_network_interface
  ]
}

#Create configure for OpenVPN instance

resource "aws_security_group" "Open_VPN" {
  vpc_id = aws_vpc.Mega.id
  name = "Mega secure VPN group"
  dynamic "ingress" {
    for_each = [ "80", "443", "22", "1194", "943", "3000", "9090", "9100" ]
    content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress  {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } 
  tags = {
    "Name"  = "Dynamic VPN Security Group"
    "Owner" = "Bakurevych Maxim" 
}  
}

resource "aws_network_interface" "Open_VPN" {
  subnet_id = aws_subnet.Public_Subnet[0].id
  security_groups = [aws_security_group.Open_VPN.id]
}

resource "aws_instance" "Open_VPN" {
  ami = data.aws_ami.latest_ubuntu.id
  key_name = "CI_CD"
  instance_type = "t2.micro"
  user_data = <<EOF
#!/bin/bash
sudo su
apt update && apt -y install ca-certificates wget net-tools gnupg
wget https://as-repository.openvpn.net/as-repo-public.asc -qO /etc/apt/trusted.gpg.d/as-repository.asc
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/as-repository.asc] http://as-repository.openvpn.net/as/debian jammy main">/etc/apt/sources.list.d/openvpn-as-repo.list
EOF
#apt update && apt -y install openvpn-as to white after install to knew password

  network_interface {
    network_interface_id = aws_network_interface.Open_VPN.id
    device_index         = 0
  }
  tags = {
    "Name" = "Instance in Public Subnet with OpenVPN"
  }
}


# #Adjustments for s3 remote states, untags after create project
# resource "aws_s3_bucket" "tfstate" {
#   bucket = "bakur-tfstate-bucket"
#   versioning {
#     enabled = true
#   }
#   lifecycle {
#     prevent_destroy = true
#   }
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }
# resource "aws_dynamodb_table" "terraform_locks" {
#   name           = "terraform-state-locking"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }
# #Bucket for CI_CD
# resource "aws_s3_bucket" "webbakurdeploy" {
#   bucket = "webbakurdeploy"
#   versioning {
#     enabled = true
#   }
#   lifecycle {
#     prevent_destroy = true
#   }
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }
# }


