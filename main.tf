resource "aws_key_pair" "ssh_pubkey" {
  key_name   = "${var.resource_prefix}-ssh-pubkey"
  public_key = var.pubkey_data != null ? var.pubkey_data : (fileexists(var.pubkey_path) ? file(var.pubkey_path) : "")
}

resource "aws_vpc" "base_vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags                 = { Name = "${var.resource_prefix}-MainVPC" }
}

resource "aws_internet_gateway" "internet_gw" {
  vpc_id = aws_vpc.base_vpc.id
  tags   = { Name = "${var.resource_prefix}-InternetGateway" }
}

resource "aws_subnet" "public_subnets" {
  for_each = {
    for cidr in var.public_subnets_cidr_list :
    substr(data.aws_availability_zones.this.names[index(var.public_subnets_cidr_list, cidr)], -2, -1) => {
      subnet_cidr_block = cidr
      availability_zone = data.aws_availability_zones.this.names[index(var.public_subnets_cidr_list, cidr)]
    }
  }
  vpc_id                  = aws_vpc.base_vpc.id
  cidr_block              = each.value.subnet_cidr_block
  map_public_ip_on_launch = true
  availability_zone       = each.value.availability_zone
  tags                    = { Name = "${var.resource_prefix}-PublicSubnet-${each.key}", "kubernetes.io/role/elb" = 1 }
}

resource "aws_subnet" "internal_subnets" {
  for_each = {
    for cidr in var.internal_subnets_cidr_list :
    substr(data.aws_availability_zones.this.names[index(var.internal_subnets_cidr_list, cidr)], -2, -1) => {
      subnet_cidr_block = cidr
      availability_zone = data.aws_availability_zones.this.names[index(var.internal_subnets_cidr_list, cidr)]
    }
  }
  vpc_id                  = aws_vpc.base_vpc.id
  cidr_block              = each.value.subnet_cidr_block
  map_public_ip_on_launch = false
  availability_zone       = each.value.availability_zone
  tags                    = { Name = "${var.resource_prefix}-InternalSubnet-${each.key}", "kubernetes.io/role/internal-elb" = 1 }
}

resource "aws_subnet" "node_subnets" {
  for_each = {
    for cidr in var.node_subnets_cidr_list :
    substr(data.aws_availability_zones.this.names[index(var.node_subnets_cidr_list, cidr)], -2, -1) => {
      subnet_cidr_block = cidr
      availability_zone = data.aws_availability_zones.this.names[index(var.node_subnets_cidr_list, cidr)]
    }
  }
  vpc_id                  = aws_vpc.base_vpc.id
  cidr_block              = each.value.subnet_cidr_block
  map_public_ip_on_launch = false
  availability_zone       = each.value.availability_zone
  tags                    = { Name = "${var.resource_prefix}-NodeSubnet-${each.key}" }
}

resource "aws_eip" "nat_eips" {
  for_each = aws_subnet.public_subnets
}

#resource "null_resource" "this" {
#  provisioner "local-exec" {
#    command = <<-EOF
#      export EKS_REGION=${data.aws_region.this.name}
#      export VPC_ID=${aws_vpc.base_vpc.id}
#      export EKS_AZ1=${aws_subnet.node_subnets[0].availability_zone}
#      export EKS_AZ2=${aws_subnet.node_subnets[1].availability_zone}
#      export EKS_AZ3=${aws_subnet.node_subnets[2].availability_zone}
#      export EKS_SUBNET_ID1=${aws_subnet.node_subnets[0].id}
#      export EKS_SUBNET_ID2=${aws_subnet.node_subnets[1].id}
#      export EKS_SUBNET_ID3=${aws_subnet.node_subnets[2].id}
#      envsubst < template/private-cluster.yaml.tmpl > out/private-cluster.yaml
#    EOF
#  }
#  depends_on = [aws_subnet.node_subnets]
#}

resource "aws_nat_gateway" "nat_gws" {
  for_each      = aws_subnet.public_subnets
  subnet_id     = aws_subnet.public_subnets[each.key].id
  allocation_id = aws_eip.nat_eips[each.key].id
  depends_on    = [aws_internet_gateway.internet_gw]
  tags          = { Name = "${var.resource_prefix}-NATGateway${each.key}" }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.base_vpc.id
  tags   = { Name = "${var.resource_prefix}-PublicRouteTable" }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gw.id
}

resource "aws_route_table_association" "pubsub_rt_assoc" {
  for_each       = aws_subnet.public_subnets
  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.public_route_table.id
}

# Need 1 private route table in each AZ to ensure they point to the correct NAT GW in the same AZ
resource "aws_route_table" "priv2nat_subnet_route_tables" {
  for_each = aws_subnet.public_subnets
  vpc_id   = aws_vpc.base_vpc.id
  tags     = { Name = "${var.resource_prefix}-PrivateToNATSubnetRouteTable${each.key}" }
}

resource "aws_route" "node_route_nat_gateways" {
  for_each               = aws_route_table.priv2nat_subnet_route_tables
  route_table_id         = aws_route_table.priv2nat_subnet_route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gws[each.key].id
}

resource "aws_route_table_association" "node_rt_assocs" {
  for_each       = aws_subnet.node_subnets
  subnet_id      = aws_subnet.node_subnets[each.key].id
  route_table_id = aws_route_table.priv2nat_subnet_route_tables[each.key].id
}
resource "aws_route_table_association" "internal_rt_assocs" {
  for_each       = aws_subnet.internal_subnets
  subnet_id      = aws_subnet.internal_subnets[each.key].id
  route_table_id = aws_route_table.priv2nat_subnet_route_tables[each.key].id
}

resource "aws_security_group" "bastionsecgrp" {
  name        = "${var.resource_prefix}-cloudkube-sg"
  description = "security group for bastion"
  vpc_id      = aws_vpc.base_vpc.id

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.resource_prefix}-BastionSecurityGroup" }
}

resource "aws_iam_role" "bastion_instance_role" {
  name = "${var.resource_prefix}-bastion-inst-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Statement1"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = { Name = "${var.resource_prefix}-Bastion-Instance-Role" }
}

resource "aws_iam_policy" "bastion_eks_policy" {
  name        = "${var.resource_prefix}-bastion_eks_policy"
  description = "bastion to allow awscli administrative activities from instance role."
  policy      = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "eks:Describe*",
          "eks:List*",
          "appmesh:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      },
      {
        "Action": [
          "iam:CreatePolicy",
          "iam:ListPolicies",
          "sts:DecodeAuthorizationMessage"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "bastion_role_eks_policy_attachment" {
  role       = aws_iam_role.bastion_instance_role.name
  policy_arn = aws_iam_policy.bastion_eks_policy.arn
}

resource "aws_iam_role_policy_attachment" "bastion_role_ssm_policy_attachment" {
  role       = aws_iam_role.bastion_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "inst_profile" {
  name = "${var.resource_prefix}-inst-profile"
  role = aws_iam_role.bastion_instance_role.name
}

resource "aws_launch_template" "bastion_launch_template" {
  name          = "${var.resource_prefix}-bastion-launch-template"
  key_name      = aws_key_pair.ssh_pubkey.key_name
  instance_type = var.instance_type
  user_data     = data.cloudinit_config.bastion_cloudinit.rendered
  image_id      = var.preferred_ami_id != "" ? data.aws_ami.preferred_ami[0].id : data.aws_ami.default_ami.id

  iam_instance_profile {
    name = aws_iam_instance_profile.inst_profile.name
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  block_device_mappings {
    device_name = var.preferred_ami_id != "" ? data.aws_ami.preferred_ami[0].root_device_name : data.aws_ami.default_ami.root_device_name
    ebs {
      volume_size = 100
      encrypted   = true
    }
  }
  vpc_security_group_ids = [aws_security_group.bastionsecgrp.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      prefix  = var.resource_prefix
      purpose = "bastion"
      Name    = "${var.resource_prefix}-bastion"
    }
  }
}

resource "aws_autoscaling_group" "bastion_host_asg" {
  vpc_zone_identifier = [for subnet in aws_subnet.internal_subnets : subnet.id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  name                = "${var.resource_prefix}-bastion-asg"

  launch_template {
    id      = aws_launch_template.bastion_launch_template.id
    version = aws_launch_template.bastion_launch_template.latest_version
  }
}
