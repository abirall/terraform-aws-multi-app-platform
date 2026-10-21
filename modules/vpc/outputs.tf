output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private.id]
}

output "database_subnet_ids" {
  description = "Isolated private subnet IDs reserved for the RDS database tier."
  value       = [aws_subnet.database_1.id, aws_subnet.database_2.id]
}
