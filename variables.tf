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

variable "ec2_config" {
  description = "EC2 instance configuration.\n `InstanceType` must be amd64 Linux Instance; \n `PublicKeyData` is the Public Key (RSA or ED25519) of the administrator; used when deploying from Terraform Cloud; overriden by valid *PublicKeyPath* value;  \n `PublicKeyPath` is the local file path to the public key. Used when deploying from an environment with access to the public key on the file system."
  type = object({
    InstanceType   = string
    PublicKeyData  = string
    PublicKeyPath  = string
    PreferredAmiId = string
  })
  default = {
    InstanceType   = "t2.micro" # must be an EBS-optimized instance type with amd64 CPU architecture.
    PublicKeyData  = null
    PublicKeyPath  = "~/.ssh/id_rsa.pub"
    PreferredAmiId = ""
  }
  validation {
    condition     = (var.ec2_config.PublicKeyData != null && var.ec2_config.PublicKeyData != "") || (var.ec2_config.PublicKeyPath != null && var.ec2_config.PublicKeyPath != "")
    error_message = "Must specify one of ec2_config.PublicKeyData and ec2_config.PublicKeyPath."
  }
  validation {
    condition = (
      var.ec2_config.PublicKeyPath == null || var.ec2_config.PublicKeyPath == "" ||
      can(regex("^(ssh-rsa|ssh-ed25519) [A-Za-z0-9+/=]+( [^ ]+)?$", file(var.ec2_config.PublicKeyPath)))
    )
    error_message = "If provided, the file must exist and contain a valid RSA (ssh-rsa) or ED25519 (ssh-ed25519) public key in OpenSSH format."
  }
  validation {
    condition = (
      var.ec2_config.PublicKeyData == null || var.ec2_config.PublicKeyData == "" || can(regex("^(ssh-rsa|ssh-ed25519) [A-Za-z0-9+/=]+( [^ ]+)?$", var.ec2_config.PublicKeyData))
    )
    error_message = "If provided, var.ec2_config.PublicKeyData must be in a valid OpenSSH format (starting with 'ssh-rsa' or 'ssh-ed25519')."
  }
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
