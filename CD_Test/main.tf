terraform {
    required_providers {
        aws = {
          source  = "hashicorp/aws"
          version =  "~> 4.0"
        }
    }
    required_version = "~> 1.6.6"
}

provider "aws" {
    region = var.aws_region
    profile = "alma-artists" # This is the profile I used for testing
}

# Data object will hold all the availability zones in our region

data "aws_availability_zones" "available" {
    state = "available"
}

# Create vpc

resource "aws_vpc" "cd_vpc" {

# Set CIDR block of vpc to the "vpc_cidr_block" variable

cidr_block           = var.vpc_cidr_block

#Enable DNS hostnames for the vpc

enable_dns_hostnames = true

# Create tag

tags = {
    Name = "cd_vpc"
  }
}

#Create IG and attach it to vpc

resource "aws_internet_gateway" "cd_igw" {

    # attach

vpc_id = aws_vpc.cd_vpc.id

# Create tag

tags = {
    Name = "cd_igw"
  }
}

# Create group of public subnets based on the variable subnet_count.public

resource "aws_subnet" "cd_public_subnet" {

# count is the number of resources I wnant to create. I am referencing the subnet_count.public variable, which is assigned to 2, so 2 public subnets will be created.

    count          = var.subnet_count.public

    # Put subnet into the "cd_vpc"

    vpc_id         = aws_vpc.cd_vpc.id

    # I am taking a CIDR block from the "public_subnet_cidr_blocks" variable. As it is a list I need to take the element based on count, which is going to be 10.0.1.0/24, and 10.0.2.0/24

    cidr_block     = var.public_subnet_cidr_blocks[count.index]

    # I am taking the availability zone from the data block. This is also a list, so are taking the name of the element based on count. As my count is 1 this should mean that my region az is eu-west-2a

    availability_zone = data.aws_availability_zones.available.names[count.index]

# Create tag

    tags = {
        Name = "cd_public_subnet_${count.index}"
    }
}

# Create group of private subnets based on the variable subnet_count.private

resource "aws_subnet" "cd_private_subnet" {

# As above, but for private

    count        = var.subnet_count.private

    # Put subnet into vpc

    vpc_id        = aws_vpc.cd_vpc.id

       # I am taking a CIDR block from the "private_subnet_cidr_blocks" variable. As it is a list I need to take the element based on count, which is going to be 10.0.101.0/24, and 10.0.102.0/24

    cidr_block    = var.private_subnet_cidr_blocks[count.index]

    # I am taking the availablilty zond from the data object created earlier. This is a list, so is created based on count. The count is 2, my region eu-west-2 this should include eu-west-2a and eu-west-2b

    availability_zone = data.aws_availability_zones.available.names[count.index]

    # Create tag

    tags = {
        Name = "cd_private_subnet_${count.index}"
    }
}

#Create a public route table

resource "aws_route_table" "cd_public_rt" {

    # Add to VPC

    vpc_id = aws_vpc.cd_vpc.id

# Add access to internet with "cd_igw"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id  = aws_internet_gateway.cd_igw.id
    }
}

# Add public subnets to public route table

resource "aws_route_table_association" "public" {

# Count is the number of subnets I want to associate with this route table. I am using the "subnet_count.public" variable. 

    count          = var.subnet_count.public

    # Confirmation of the route table

    route_table_id = aws_route_table.cd_public_rt.id

    # This is the subnet IK. As "cd_public_subnet" is a list of the public subnets I need to use count to aquire the index and then the id of the subnet

    subnet_id      = aws_subnet.cd_public_subnet[count.index].id
}

# Create private route table

resource "aws_route_table" "cd_private_rt" {

# Put route table in VPC

    vpc_id = aws_vpc.cd_vpc.id

    # This is private so no route

}

# Add private subnets to route table "cd_private_rt"

resource "aws_route_table_association" "private" {

    # count is the number of subnets I want to associate with the route table. I'm using the subnet_count.private variable, which is 2, so I will be adding 2 private subnets

    count          = var.subnet_count.private

# Confirmation of route aws_route_table

    route_table_id = aws_route_table.cd_private_rt.id

# This is a list of private subnets I use count to access the subnet elements and ID of the subnet

    subnet_id      = aws_subnet.cd_private_subnet[count.index].id
}

#Create as security group for the EC2 instances

resource "aws_security_group" "cd_web_sg" {
    name        = "cd_web_sg"
    description = "Security group for cd web servers"
    vpc_id      = aws_vpc.cd_vpc.id

    # Inbound rule via HTTP on TCP port 80

    ingress {
        description = "Allow all traffic through HTTP"
        from_port   = "80"
        to_port     = "80"
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # SSH inbound rule

    ingress {
        description = "Allow SSH from my machine"
        from_port   = "22"
        to_port     = "22"
        protocol    = "tcp"

        #Use variable "my_ip"

        cidr_blocks = ["${var.my_ip}/32"]
    }

    # Outbound rule for all traffic

    egress {
        description = "Allow all outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "cd_web_sg"
    }
}


# Create a security group for the RDS instance.

resource "aws_security_group" "cd_db_sg" {
    name        = "cd_db_sg"
    description = "Security group for cd database"
    vpc_id      = aws_vpc.cd_vpc.id

    #Keep RDS on private subnet and inaccessible to internet, so no inbound or outbound rules.

    ingress {
        description       = "Allow MySQL traffic from only the web sg"
        from_port         = "3306"
        to_port           = "3306"
        protocol          = "tcp"
        security_groups   = [aws_security_group.cd_web_sg.id]
    }

    tags = {
        Name = "cd_db_sg"
    }
}

#Create a db subnet security_groups

resource "aws_db_subnet_group" "cd_db_subnet_group" {
    name        = "cd_db_subnet_group"
    description = "DB subnet group for cd"
    subnet_ids  = [for subnet in aws_subnet.cd_private_subnet : subnet.id]
}

#Create database

resource "aws_db_instance" "cd_database" {
    allocated_storage       = var.settings.database.allocated_storage
    max_allocated_storage   = var.settings.database.max_allocated_storage
    storage_type            = var.settings.database.storage_type
    engine                  = var.settings.database.engine
    engine_version          = var.settings.database.engine_version
    instance_class          = var.settings.database.instance_class
    db_name                 = var.settings.database.db_name
    username                = var.db_username
    password                = var.db_password
    multi_az                = var.settings.database.multi_az
    backup_retention_period = var.settings.database.backup_retention_period
    backup_window           = var.settings.database.backup_window
    db_subnet_group_name    = aws_db_subnet_group.cd_db_subnet_group.id
    vpc_security_group_ids  = [aws_security_group.cd_db_sg.id]
    skip_final_snapshot     = var.settings.database.skip_final_snapshot
}

resource "aws_key_pair" "cd_kp" {
    key_name   = "cd_kp"
    public_key = file("cd_kp.pub")
}

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

# create EC2s

resource "aws_instance" "cd_web" {
    count                  = var.settings.web_app.count
    ami                    = data.aws_ami.ubuntu.id
    instance_type          = var.settings.web_app.instance_type
    subnet_id              = aws_subnet.cd_public_subnet[count.index].id
    key_name               = aws_key_pair.cd_kp.key_name
    vpc_security_group_ids = [aws_security_group.cd_web_sg.id]

    tags = {
        Name = "cd_web_${count.index}"
    }
}

# Create elastic instance_type

resource "aws_eip" "cd_web_eip" {
    count     = var.settings.web_app.count
    instance  = aws_instance.cd_web[count.index].id
    vpc       = true
    
    tags = {
        Name = "cd_web_eip-${count.index}"
    }
}