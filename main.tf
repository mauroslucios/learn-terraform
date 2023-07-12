resource "aws_vpc" "infoservice" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "developer_public_subnet" {
  vpc_id                  = aws_vpc.infoservice.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "infoservice_gateway" {
  vpc_id = aws_vpc.infoservice.id

  tags = {
    "Value" : "dev_igw",
    "Key" : "Name"

  }
}

resource "aws_route_table" "infoservice_public_rt" {
  vpc_id = aws_vpc.infoservice.id

  tags = {
    Name = "dev_public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.infoservice_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.infoservice_gateway.id
}

resource "aws_route_table_association" "infoservice_public_assoc" {
  subnet_id      = aws_subnet.developer_public_subnet.id
  route_table_id = aws_route_table.infoservice_public_rt.id
}

resource "aws_security_group" "infoservice_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.infoservice.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev_sg"
  }
}

resource "aws_key_pair" "infoservice_auth" {
  key_name   = "infoservicekey"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.infoservice_auth.id
  vpc_security_group_ids = [aws_security_group.infoservice_sg.id]
  subnet_id              = aws_subnet.developer_public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname = self.public_ip,
      user = "ubuntu",
      identifyfile = "~/.ssh/id_rsa"
    })
    interpreter = var.host_os == "windows" ? ["Powershel","-Command"]:["bash","-c"]
  }
}