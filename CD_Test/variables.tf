# AWS Default Region

variable "aws_region" {
  default = "eu-west-2"
}

# Variable for CIDR blocks for the VPC

variable "vpc_cidr_block" {
  description = "CIDR block for vpc"
  type        = string
  default     = "10.0.0.0/16"
}

# Variable for the number of public and private subnets

variable "subnet_count" {
  description = "Number of subnets"
  type        = map(number)
  default = {
    public  = 2,
    private = 2
  }
}

# Variable contains config for EC2 and RDS instances

variable "settings" {
  description = "Configuration settings"
  type        = map(any)
  default = {
    "database" = {
      allocated_storage       = 200
      max_allocated_storage   = 2000
      storage_type            = "gp3"
      engine                  = "mysql"
      engine_version          = "8.0.35"
      instance_class          = "db.m5d.2xlarge"
      db_name                 = "CDDB"
      multi_az                = true
      backup_retention_period = 7
      backup_window           = "03:00-04:00"
      skip_final_snapshot     = true
    },
    "web_app" = {
      count         = 2
      instance_type = "t2.large"
    }
  }
}

# This variable defines the CIDR blocks for public subnet.

variable "public_subnet_cidr_blocks" {
  description = "Available CIDR blocks for public subnets"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
  ]
}

# This variable defines the CIDR blocks for private subnet.

variable "private_subnet_cidr_blocks" {
  description = "Available DIDR blocks for private subnets"
  type        = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24",
    "10.0.104.0/24",
  ]
}

# Variable defines user IP address for SSH rule in web security group

variable "my_ip" {
  description = "My IP address"
  type        = string
  sensitive   = true
}

# This variable defines the database master user. This will be stored in the secrets file

variable "db_username" {
  description = "Database master user"
  type        = string
  sensitive   = true
}

# This variable defines the database master user password. This will be stored in the secrets file

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}