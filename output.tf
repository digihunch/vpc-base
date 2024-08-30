output "bastion" {
  value = join(",", data.aws_instances.bastion.ids)
}

output "eksctl_command" {
  value = "eksctl create cluster -f ${local_file.eksctl_yaml.filename}"
}
