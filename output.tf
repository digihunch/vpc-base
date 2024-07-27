output "bastion" {
  value = join(",", data.aws_instances.bastion.ids)
}
output "vpc_cidr" {
  value = aws_vpc.vpc.cidr_block
}
output "node_subnets_ids" {
  value = join(",", aws_subnet.node_subnets.*.id)
}
output "bastion_sg_id" {
  value = aws_security_group.bastionsecgrp.id
}
output "eksctl_command" {
  value = "eksctl create cluster -f out/private-cluster.yaml"
}
