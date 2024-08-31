variable "vpc_config" {
  type = object({
    vpc_cidr               = string
    az_count               = number
    public_subnet_pfxlen   = number
    internal_subnet_pfxlen = number
    node_subnet_pfxlen     = number
  })
  default = {
    vpc_cidr               = "147.206.0.0/16"
    az_count               = 2
    public_subnet_pfxlen   = 24
    internal_subnet_pfxlen = 22
    node_subnet_pfxlen     = 22
  }
  validation {
    condition     = can(cidrhost(var.vpc_config.vpc_cidr, 32))
    error_message = "Input variable vpc_config.vpc_cidr must be a valid IPv4 CIDR."
  }
  validation {
    condition     = var.vpc_config.az_count >= 1 && var.vpc_config.az_count <= 3
    error_message = "Input variable vpc_config.az_count must be a numeric value between 1, 2 or 3"
  }
}
variable "pubkey_data" {
  type     = string
  default  = null
  nullable = true
}
variable "instance_type" {
  type    = string
  default = "t2.micro" #g4dn.xlarge for GPU 
}
variable "preferred_ami_id" {
  type     = string
  default  = "" #ami-04b70fa74e45c3917 for ubuntu 2024 us-east-1
  nullable = true
}
variable "pubkey_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}
variable "resource_prefix" {
  type    = string
  default = "base"
}
variable "common_tags" {
  description = "Tags for every resource."
  type        = map(any)
  default = {
    Environment = "Dev"
    Owner       = "my@digihunch.com"
  }
}
