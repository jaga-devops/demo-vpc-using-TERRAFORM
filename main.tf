provider "aws" {
      region     = "${var.region}"
      access_key = "${var.access_key}"
      secret_key = "${var.secret_key}"
}

#CREATING 1 VPC
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "OWN-VPC"
  }
}

#CREATE PUBLIC SUBNET1
resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet1_cidr_block
  map_public_ip_on_launch = true #THIS WILL ENABLE PUBLIC IP OF INSTANCE WHICH WILL BECREATED IN PUBLIC SUBNET
  tags = {
    Name = "PUBLIC-SUBNET-1"
  }
}

#CREATE PRIVATE SUBNET1
resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet1_cidr_block

  tags = {
    Name = "PRIVATE-SUBNET-1"
  }
}
#CREATE INTERNET GATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "OWN-main"
  }
}

#CREATING ELASTIC IP WHICH WILL BW ASSOCIATED WITH NAT GATEWAY
resource "aws_eip" "EIP1" {
  tags = {
    Env = "dev"
  }
}

#CREATE NAT GATEWAY IN PUBLIC SUBNET 
resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.EIP1.id #NATGATEWAY SHOULD HAVE ELASTIC IP
  subnet_id     = aws_subnet.public1.id #VVIMP IT's ALWAYS RECOMMENDED THAT NAT GATEWAY SHOULD BE CREATED IN PUBLIC SUBNET

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

#CREATING PUBLIC ROUTE TABLE
resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "PUBLIC-RT-1"
  }
}

#CREATING ROUTE FOR PUBLIC ROUTE TABLE
resource "aws_route" "public" {
  route_table_id         = aws_route_table.publicRT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

#SUBNET ASSOCIATE WITH ROUTE OF PUBLIC ROUTE TABLE
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.publicRT.id
}

#CREATING PRIVATE ROUTE TABLE
resource "aws_route_table" "privateRT" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "PRIVATE-RT-1"
  }
}

#CREATING ROUTE FOR PRIVATE ROUTE TABLE
resource "aws_route" "private" {
  route_table_id         = aws_route_table.privateRT.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id             = aws_nat_gateway.example.id
}

#SUBNET ASSOCIATE WITH ROUTE OF PRIVATE  ROUTE TABLE
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.privateRT.id
}

