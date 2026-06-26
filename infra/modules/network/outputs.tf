output "vpc_id" { value = aws_vpc.this.id }
output "private_subnet_ids" { value = values(aws_subnet.private)[*].id }
output "redshift_security_group_id" { value = aws_security_group.redshift.id }
output "s3_endpoint_id" { value = aws_vpc_endpoint.s3.id }
