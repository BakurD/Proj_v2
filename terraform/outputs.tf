output "elb_dns_name" {
  value = aws_lb.balance.dns_name
}

output "vpc_id" {
  value = aws_vpc.Mega.id
}

output "vpc_cidr" {
  value = aws_vpc.Mega.cidr_block
}
output "security_group_id" {
  value = aws_security_group.HTTP_HTTPS_SSH.id
}

output "public_subnets_id" {
  value = aws_subnet.Public_Subnet[*].id
}

output "OpenVPN_server_ip" {
  value = aws_instance.Open_VPN.public_ip
}