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

#CREATING INSTANCES

#CREATING VPN SERVER
resource "aws_network_interface" "first_network_interface" {
  subnet_id   = aws_subnet.public1.id
  tags = {
    Name = "primary_network_interface"
  }
}

#CREATING VPN-SG

resource "aws_security_group" "VPN-SG" {
  name        = "VPN_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 19909
    to_port          = 19909
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 27017
    to_port          = 27017
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
#    cidr_blocks      = [aws_vpc.main.cidr_block]
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "VPN SECURITY GROUP"
  }
}

#resource "aws_key_pair" "deployer" {
#  key_name   = "deployer-key"
#  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdUUO00ZEdocRDh7ZINGibSTjcqLIm7a45gm9bjDfcT0Zg9eBNxQFmQdZBIllqF1PrVLfSm9dr1WhFKbpoJ7Mks7WHDwtr7xmbkiWN35wjHSjwJOTKRp1bdccrjtZMqWFgwYTh455yFcSQT3fqmM7AnhcYubWOy+9AUki/+ZU1f5FYh9gTyz6GqTxyhIz66pzgTA5zXtsXmK1HERtdSS7qYCjX5KxvflqK1/aaHHxFIZye4gSDbm1sv/4nw2+BBRG60ZULRcwcWSXoE3GrhFKpUMIXvMeTjdB5coeEgfRL7dMC4rU5c/NrsEIF/S+wGnAu344EldJCo9AG4k3UQAWT BASTION HOST"
#}

resource "aws_instance" "myfirst_instance" {
  ami           = "ami-0fb653ca2d3203ac1" # us-west-2
  instance_type = "t2.micro"
  key_name = "BASTION HOST"
  subnet_id = aws_subnet.public1.id
#  network_interface {
#    network_interface_id = aws_network_interface.first_network_interface.id
#    device_index         = 0
#  }
#  security_groups = ["VPN_SG"]
  vpc_security_group_ids = [aws_security_group.VPN-SG.id]
  tags = {
    Name = "VPN"
  }
}

#CREATE BASTION HOST SG

resource "aws_security_group" "BASTION-HOST-SG" {
  name        = "BASTION-HOST-SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "BASTION HOST SECURITY GROUP"
  }
}


#ADDING INBOUND RULE FOR BASTION HOST SECURITY GROUP
resource "aws_security_group_rule" "BASTION-HOST-SG-RULE" {
  security_group_id = aws_security_group.BASTION-HOST-SG.id
  type              = "ingress"
  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  source_security_group_id = aws_security_group.VPN-SG.id
#  cidr_blocks      = ["0.0.0.0/0"]
}

#ADDING OUTBOUND RULE FOR BASTION HOST SECURITY GROUP
resource "aws_security_group_rule" "BASTION-HOST-SG-OUTBOUND-RULE" {
  security_group_id = aws_security_group.BASTION-HOST-SG.id
  type              = "egress"
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
}


#
#
#  egress {
#    from_port        = 0
#    to_port          = 0
#    protocol         = "-1"
#    cidr_blocks      = ["0.0.0.0/0"]
#  }
#
#  tags = {
#    Name = "BASTION-HOST SECURITY GROUP"
#  }


#CREATE BASTION HOST

resource "aws_instance" "bastion_host_server" {
  ami           = "ami-0fb653ca2d3203ac1" # us-west-2
  instance_type = "t2.micro"
  key_name = "BASTION HOST"
  subnet_id = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.BASTION-HOST-SG.id]
  tags = {
    Name = "BASTION HOST"
  }
}

#CREATE BLISS APP SG
resource "aws_security_group" "BLISS-APP-SG" {
  name        = "BLISS-APP-SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "BLISS APP SECURITY GROUP"
  }
}


#ADDING INBOUND RULE FOR BLISS APP SECURITY GROUP
resource "aws_security_group_rule" "BLISS-APP-SG-RULE" {
  security_group_id = aws_security_group.BLISS-APP-SG.id
  type              = "ingress"
  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  source_security_group_id = aws_security_group.BASTION-HOST-SG.id
#  cidr_blocks      = ["0.0.0.0/0"]
}

#ADDING OUTBOUND RULE FOR BASTION HOST SECURITY GROUP
resource "aws_security_group_rule" "BLISS-APP-SG-OUTBOUND-RULE" {
  security_group_id = aws_security_group.BLISS-APP-SG.id
  type              = "egress"
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
}

#CREATE BLISS APP SERVER

#CREATE BASTION HOST

resource "aws_instance" "bliss_app_server" {
  ami           = "ami-0fb653ca2d3203ac1" # us-west-2
  instance_type = "t2.micro"
  key_name = "BASTION HOST"
  subnet_id = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.BLISS-APP-SG.id]
  tags = {
    Name = "BLISS APP"
  }
}

