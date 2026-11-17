provider "aws" {
  region = "eu-west-3"
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.12.20260914.0-kernel-6.18-arm64"] # celui quye claude a trouvé quand il m'a fait le md de l'infra de l'école
  }

  owners = ["137112412989"]
}

resource "aws_vpc" "kube_vpc" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "kube_vpc"
  }
}

resource "aws_security_group" "kube_security_group" {
  name   = "kube_security_group"
  vpc_id = aws_vpc.kube_vpc.id

  tags = {
    Name = "kube_security_group"
  }

  depends_on = [aws_vpc.kube_vpc]
}

resource "aws_vpc_security_group_ingress_rule" "allow_80" {
  security_group_id = aws_security_group.kube_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = {
    Name = "allow_80"
  }

  depends_on = [aws_security_group.kube_security_group]
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls" {
  security_group_id = aws_security_group.kube_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443

  tags = {
    Name = "allow_tls"
  }

  depends_on = [aws_security_group.kube_security_group]
}

resource "aws_vpc_security_group_ingress_rule" "allow_all_from_sg" {
  security_group_id            = aws_security_group.kube_security_group.id
  referenced_security_group_id = aws_security_group.kube_security_group.id
  ip_protocol                  = "-1"

  tags = {
    Name = "allow_all_from_sg"
  }

  depends_on = [aws_security_group.kube_security_group]
}

resource "aws_vpc_security_group_egress_rule" "allow_all_out" {
  security_group_id = aws_security_group.kube_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name = "allow_all_out"
  }

  depends_on = [aws_security_group.kube_security_group]
}

resource "aws_internet_gateway" "kube_igw" {
  vpc_id = aws_vpc.kube_vpc.id

  tags = {
    Name = "kube_igw"
  }

  depends_on = [aws_vpc.kube_vpc]
}

resource "aws_subnet" "kube_public_subnet" {
  vpc_id                  = aws_vpc.kube_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "kube_public_subnet"
  }

  depends_on = [aws_internet_gateway.kube_igw]
}

resource "aws_route_table" "kube_route_table" {
  vpc_id = aws_vpc.kube_vpc.id

  route {
    cidr_block = "10.0.0.0/24"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/24"
    gateway_id = aws_internet_gateway.kube_igw.id
  }

  tags = {
    Name = "kube_route_table"
  }

  depends_on = [aws_internet_gateway.kube_igw, aws_vpc.kube_vpc]
}

resource "aws_instance" "kube_node" {
  count = 3

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.kube_public_subnet.id

  tags = {
    Name = "kube_node-${count.index}"
  }

  depends_on = [aws_subnet.kube_public_subnet]
}

resource "aws_eip" "kube_eip" {
  domain   = "vpc"
  instance = aws_instance.kube_node[0].id

  tags = {
    Name = "kube_eip"
  }

  depends_on = [aws_instance.kube_node[0]]
}

output "instance_infos" {
  description = "ec2 instances infos"
  value = {
    for idx, instance in aws_instance.kube_node : instance.tags.Name => merge({
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    },
    idx == 0 ? {eip = aws_eip.kube_eip.public_ip} : {}
  )}
}