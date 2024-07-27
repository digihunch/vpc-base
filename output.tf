output "bastion" {
  value = join(",", data.aws_instances.bastion.ids)
}
output "vpc_cidr" {
  value = aws_vpc.base_vpc.cidr_block
}
output "node_subnets_ids" {
  value = join(",", aws_subnet.node_subnets.*.id)
}
output "bastion_sgid" {
  value = aws_security_group.bastionsecgrp.id
}
output "eksctl_command" {
  value = "eksctl create cluster -f out/private-cluster.yaml"
}
