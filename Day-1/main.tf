resource "aws_vpc" "name" {
    cidr_block = "10.0.0.0/24"
    tags = {
        Name = "my-vpc"
    }
}