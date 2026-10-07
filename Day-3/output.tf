output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "subnet_ids" {
  value = [aws_subnet.main.id, aws_subnet.main2.id]
}