variable "region" { default = "ap-northeast-1" }

resource "aws_vpc" "isucon" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "isucon"
  }
}

resource "aws_subnet" "public_0" {
  vpc_id                  = aws_vpc.isucon.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.isucon.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "isucon" {
  vpc_id = aws_vpc.isucon.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.isucon.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.isucon.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private_0" {
  vpc_id                  = aws_vpc.isucon.id
  cidr_block              = "10.0.65.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.isucon.id
  cidr_block              = "10.0.66.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = false
}

resource "aws_eip" "nat_gateway_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.isucon]
}

resource "aws_eip" "nat_gateway_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.isucon]
}

resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_gateway_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on    = [aws_internet_gateway.isucon]
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_gateway_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.isucon]
}

resource "aws_route_table" "private_0" {
  vpc_id = aws_vpc.isucon.id
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.isucon.id
}

resource "aws_route" "private_0" {
  route_table_id         = aws_route_table.private_0.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_0.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
  route_table_id         = aws_route_table.private_1.id
  nat_gateway_id         = aws_nat_gateway.nat_gateway_1.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "private_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

variable "key_name" {
  type        = string
  description = "isucon-qualifer keypair name"
  # キーペア名はここで指定
  default = "isucon-qualifer"
}

locals {
  public_key_file  = "./private/${var.key_name}.id_rsa.pub"
  private_key_file = "./private/${var.key_name}.id_rsa"
}

resource "tls_private_key" "keygen" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_pem" {
  filename = local.private_key_file
  content  = tls_private_key.keygen.private_key_pem
  provisioner "local-exec" {
    command = "chmod 600 ${local.private_key_file}"
  }
}

resource "local_file" "public_key_openssh" {
  filename = local.public_key_file
  content  = tls_private_key.keygen.public_key_openssh
  provisioner "local-exec" {
    command = "chmod 600 ${local.public_key_file}"
  }
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.keygen.public_key_openssh

}

### Bastion
# module "bastion" {
#   source            = "hazelops/ec2-bastion/aws"
#   version           = "~> 2.0"
#   aws_profile       = "private_aws"
#   env               = "isucon"
#   ec2_key_pair_name = aws_key_pair.key_pair.key_name
#   vpc_id            = aws_vpc.isucon.id
#   private_subnets   = [aws_subnet.private_0.id, aws_subnet.private_1.id]
# }

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = "MyRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy" "systems_manager" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.systems_manager.arn
}

resource "aws_iam_instance_profile" "systems_manager" {
  name = "MyInstanceProfile"
  role = aws_iam_role.role.name
}

resource "aws_instance" "private" {
  ami                  = "ami-0f310fced6141e627"
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.systems_manager.name
  subnet_id            = aws_subnet.private_0.id
  key_name             = aws_key_pair.key_pair.key_name
}

### EC2
# resource "aws_instance" "participant-instance" {
#   ami = data.aws_ami.standalone_ami.id
#   count = length(var.ec2_members)
#   instance_type = var.ec2_instance_type
#   subnet_id = var.subnet_id
#   associate_public_ip_address = true
#   key_name = aws_key_pair.participant-key.id
#   security_groups = [var.security_group_id]

#   root_block_device {
#     volume_type           = "standard"
#     volume_size           = var.ec2_volume_size
#     delete_on_termination = true
#   }

#   tags = {
#     Name = format("isucon-%s", lookup(var.ec2_members, count.index))
#   }
# }
module "isucon_ec2_sg" {
  source      = "./security_group"
  name        = "module-sg"
  vpc_id      = aws_vpc.isucon.id
  port        = 80
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_instance" "participant-instance" {
  ami                         = "ami-0796be4f4814fc3d5" # isucon 11
  count                       = 1
  instance_type               = "t2.micro" # "c5.large"
  subnet_id                   = aws_subnet.private_0.id
  associate_public_ip_address = false
  key_name                    = aws_key_pair.key_pair.key_name
  # security_groups             = [module.isucon_ec2_sg.security_group_id]

  root_block_device {
    volume_type           = "standard"
    volume_size           = 30
    delete_on_termination = true
  }

  # tags = {
  #   Name = format("isucon-%s", lookup(var.ec2_members, count.index))
  # }
}


# resource "aws_instance" "participant-instance" {
#   ami           = "ami-03bbe60df80bdccc0" # isucon 11
#   count         = 1
#   instance_type = "c5.large"
#   key_name      = aws_key_pair.key_pair.key_name
#   subnet_id     = aws_subnet.public_1.id
# }
