output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, one per zone."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs, one per zone."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_count" {
  description = "Number of NAT gateways created."
  value       = length(aws_nat_gateway.this)
}
