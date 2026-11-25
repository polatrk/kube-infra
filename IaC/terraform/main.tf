provider "aws" {
  region = "eu-west-3"
}

# on définit l'image utilisée pour les vms
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.12.20260914.0-kernel-6.18-arm64"] # celui quye claude a trouvé quand il m'a fait le md de l'infra de l'école
  }

  owners = ["137112412989"]
}

# on créer le vpc donc notre network
resource "aws_vpc" "kube_vpc" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "kube_vpc"
  }
}

# on ajt un security group qui nous sert de fw qui sera appliqué sur toutes les vm mais ca sert seulement à node_0 pcq c la seule vm qui a une ip publique. Bizarre qu'Epitech on configuré comme ca
resource "aws_security_group" "kube_security_group" {
  name   = "kube_security_group"
  vpc_id = aws_vpc.kube_vpc.id

  tags = {
    Name = "kube_security_group"
  }

  depends_on = [aws_vpc.kube_vpc]
}

# on autorise à accéder au port 80 depuis n'importe quelle ip
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

# on autorise à accéder au port 443 depuis n'importe quelle ip
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

# on autorise à accéder au port 443 depuis n'importe quelle VMs qui fait partie du security group
resource "aws_vpc_security_group_ingress_rule" "allow_all_from_sg" {
  security_group_id            = aws_security_group.kube_security_group.id
  referenced_security_group_id = aws_security_group.kube_security_group.id
  ip_protocol                  = "-1"

  tags = {
    Name = "allow_all_from_sg"
  }

  depends_on = [aws_security_group.kube_security_group]
}

# on autorise les vm à accéder à n'importe quoi
resource "aws_vpc_security_group_egress_rule" "allow_all_out" {
  security_group_id = aws_security_group.kube_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name = "allow_all_out"
  }

  depends_on = [aws_security_group.kube_security_group]
}

# on créer la gateway vers internet
resource "aws_internet_gateway" "kube_igw" {
  vpc_id = aws_vpc.kube_vpc.id

  tags = {
    Name = "kube_igw"
  }

  depends_on = [aws_vpc.kube_vpc]
}

# on fait le subnet public qui sera relié à internet
resource "aws_subnet" "kube_public_subnet" {
  vpc_id                  = aws_vpc.kube_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "kube_public_subnet"
  }

  depends_on = [aws_internet_gateway.kube_igw]
}

# on route le subnet public vers local et tout le reste vers internet
resource "aws_route_table" "kube_route_table" {
  vpc_id = aws_vpc.kube_vpc.id

  route {
    cidr_block = "10.0.0.0/24"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kube_igw.id
  }

  tags = {
    Name = "kube_route_table"
  }

  depends_on = [aws_internet_gateway.kube_igw, aws_vpc.kube_vpc]
}

# on relie le subnet à la route table
resource "aws_route_table_association" "kube_rta" {
  subnet_id = aws_subnet.kube_public_subnet.id
  route_table_id = aws_route_table.kube_route_table.id
}

# on définit les instances
resource "aws_instance" "kube_node" {
  count = 3 # on fait 3 instances

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.kube_public_subnet.id
  vpc_security_group_ids = [ aws_security_group.kube_security_group.id ]

  user_data = file("./cloud-init/kube_node-init.yml") # on pointe vers le fichier de config du cloud-init pr créer le user ansible qui sera utilisé par Ansible du coup

  tags = {
    Name = "kube_node-${count.index}" # on sépare les vm via leur nom pour les identifier plus facilement
  }

  depends_on = [aws_subnet.kube_public_subnet]
}

# on créer une ip persistente pour la node master
resource "aws_eip" "kube_eip" {
  domain   = "vpc"
  instance = aws_instance.kube_node[0].id # ici on prend l'index 0 des instances créer car c'est elle qui va etre le master sur le cluster kubernetes

  tags = {
    Name = "kube_eip"
  }

  depends_on = [aws_instance.kube_node[0]]
}

# on met dans l'output les infos de chaque vm
output "instance_infos" {
  description = "ec2 instances infos"
  value = {
    for idx, instance in aws_instance.kube_node : instance.tags.Name => merge({
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
    },
    idx == 0 ? {eip = aws_eip.kube_eip.public_ip} : {} # si l'index est 0 donc la vm master, on ajt à l'output aussi son eip associée
  )}
}