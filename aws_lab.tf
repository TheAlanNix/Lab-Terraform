provider "aws" {
  region = var.region
}

/*
  Create VPC
 */
resource "aws_vpc" "main" {
  cidr_block = var.vpc_subnet

  tags = {
    "Name" = var.vpc_name
  }
}

/*
  Store the network bits from the CIDR
 */
locals {
  vpc_network_bits = 24 - tonumber(split("/", var.vpc_subnet)[1])
}

/*
  Create Internet Gateway
 */
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${var.vpc_name} Internet Gateway"
  }
}

/*
  Create Subnets
 */
resource "aws_subnet" "outside_subnets" {
  count = var.availability_zone_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_subnet, local.vpc_network_bits, (2 * count.index))
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    "Name" = "${var.vpc_name} Outside Subnet ${count.index + 1}"
  }
}
resource "aws_subnet" "inside_subnets" {
  count = var.availability_zone_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_subnet, local.vpc_network_bits, (2 * count.index) + 1)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    "Name" = "${var.vpc_name} Inside Subnet ${count.index + 1}"
  }
}

/*
  Create EIPs
 */
resource "aws_eip" "nat_gateway_eips" {
  count = var.availability_zone_count

  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]

  tags = {
    "Name" = "${var.vpc_name} Inside NAT Gateway EIP ${count.index + 1}"
  }
}

/*
  Create NAT Gateway
 */
resource "aws_nat_gateway" "inside_nat_gateways" {
  count = var.availability_zone_count

  allocation_id = aws_eip.nat_gateway_eips[count.index].id
  subnet_id     = aws_subnet.outside_subnets[count.index].id
  depends_on    = [aws_internet_gateway.internet_gateway]

  tags = {
    "Name" = "${var.vpc_name} Inside NAT Gateway ${count.index + 1}"
  }
}

/*
  Create Outside Route Table (IGW)
 */
resource "aws_route_table" "outside_route_table" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "${var.vpc_name} Outside Route Table"
  }
}
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.outside_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}
resource "aws_route_table_association" "route_table_association_outside" {
  count = length(aws_subnet.outside_subnets)

  subnet_id      = aws_subnet.outside_subnets[count.index].id
  route_table_id = aws_route_table.outside_route_table.id
}

/*
  Create Inside Route Table (NAT)
 */
resource "aws_route_table" "inside_route_tables" {
  count = var.availability_zone_count

  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.inside_nat_gateways[count.index].id
  }

  tags = {
    "Name" = "${var.vpc_name} Inside Route Table ${count.index + 1}"
  }
}
resource "aws_route_table_association" "inside_route_rable_association" {
  count = length(aws_subnet.inside_subnets)

  subnet_id      = aws_subnet.inside_subnets[count.index].id
  route_table_id = aws_route_table.inside_route_tables[count.index].id
}

/*
  Create "Allow SSH/HTTP/HTTPS" Security Group
 */
resource "aws_security_group" "allow_ssh_http_https" {
  name   = "${var.vpc_name} Allow SSH/HTTP/HTTPS"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "${var.vpc_name} Allow SSH/HTTP/HTTPS"
  }
}

/*
  Create AMI Images
 */
resource "aws_instance" "public_instances" {
  count = var.availability_zone_count * var.instances_per_az

  ami           = var.instance_ami
  instance_type = var.instance_size
  key_name      = var.instance_key_name
  subnet_id     = aws_subnet.outside_subnets[floor(count.index / var.instances_per_az)].id
  tags          = {
    Name = "${var.vpc_name} Public Instance ${count.index + 1}"
  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip} >> ./ansible/inventory.cfg"
  }
}

/*
  Build a Lacework config file
 */
data "template_file" "lacework_config" {
  template = "${file("${path.module}/ansible/agent_config_template.txt")}"

  vars = {
    lacework_access_token = var.lacework_access_token
  }
}

resource "local_file" "lacework_config" {
  content  = data.template_file.lacework_config.rendered
  filename = "${path.module}/ansible/config.json"
}

/*
  Attach the Security Group to Instances
 */
resource "aws_network_interface_sg_attachment" "security_group_attachment" {
  count = length(aws_instance.public_instances)

  security_group_id    = aws_security_group.allow_ssh_http_https.id
  network_interface_id = aws_instance.public_instances[count.index].primary_network_interface_id
}

output "ansible_command" {
  value = "ansible-playbook -i ansible/inventory.cfg --private-key ${var.instance_key_path} -u ${var.instance_username} ansible/install_lacework_agent_apt.yml ansible/install_docker_apt.yml"
}
