data "aws_ami" "find_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-2023.5.20240819.0-kernel-6.1-x86_64"]
  }
}
variable "file_name" {
  description = "Name of the key pair"
  type        = string
  default     = "id_rsa"
}
# RSA key of size 4096 bits
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "tf_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = var.file_name
}

resource "aws_key_pair" "deployer" {
  key_name   = "not-a-sshkey"
  public_key = tls_private_key.rsa.public_key_openssh
}

#Create VPC - 10.69.0.0/16
resource "aws_vpc" "not-a-vpc" {
  cidr_block = "10.69.0.0/16"
  tags = {
    "name" = "not-a-vpc"
  }
}
#Create Subnet - 10.69.1.0/24
resource "aws_subnet" "not-a-websunet" {
  vpc_id                  = aws_vpc.not-a-vpc.id
  cidr_block              = "10.69.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "not-a-websubnet"
  }
}

#Create Internet Gateway
resource "aws_internet_gateway" "not-a-igway" {
  vpc_id = aws_vpc.not-a-vpc.id
  tags = {
    "Name" = "not-a-igateway"
  }
}

#Create Route Table - attached with subnet
resource "aws_route_table" "not-a-rt" {
  vpc_id = aws_vpc.not-a-vpc.id
}
#Create Route in Route Table for Internet Access
resource "aws_route" "not-a-route" {
  route_table_id         = aws_route_table.not-a-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.not-a-igway.id
}

#Associate Route Table with Subnet
resource "aws_route_table_association" "not-a-rt-assoc" {
  route_table_id = aws_route_table.not-a-rt.id
  subnet_id      = aws_subnet.not-a-websunet.id
}

#Create Security Group in the VPC with port 80, 22 as inbound open
resource "aws_security_group" "not-a-sg" {
  name        = "not-a-web-ssh-sg"
  vpc_id      = aws_vpc.not-a-vpc.id
  description = "Dev web server traffic allowed ssh & http"

}

resource "aws_vpc_security_group_ingress_rule" "not-a-ingress-22" {
  security_group_id = aws_security_group.not-a-sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "not-a-ingress-80" {
  security_group_id = aws_security_group.not-a-sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "not-a-egress" {
  security_group_id = aws_security_group.not-a-sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
#ec2 instance
resource "aws_instance" "not-a-vm" {
  ami                    = data.aws_ami.find_ami.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.not-a-websunet.id
  vpc_security_group_ids = [aws_security_group.not-a-sg.id]
  key_name               = "not-a-sshkey"

  tags = {
    "Name" = "not-a-webvm"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install httpd -y",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
      "sudo sh -c 'echo NotAWebPage > /var/www/html/index.html'",
      "echo ${self.public_ip}"
    ]
    connection {
      host        = self.public_ip
      private_key = file(var.file_name)
      type        = "ssh"
      user        = "ec2-user"
    }
  }
  # provisioner "file" {
  #   connection {
  #     host        = self.public_ip
  #     private_key = file("./id_rsa")
  #     type        = "ssh"
  #     user        = "ec2-user"
  #   }
  #   content     = "This sucks"
  #   destination = "/var/www/html/index.html"
  # }
}
#elastic-ip
resource "aws_eip" "not-a-eip" {
  instance   = aws_instance.not-a-vm.id
  depends_on = [aws_internet_gateway.not-a-igway]

  provisioner "local-exec" {
    command = "echo ${self.public_ip}"
  }
}
