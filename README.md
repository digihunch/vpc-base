# VPC-base

I use this project is to provision the networking stack as the infrastructure foundation for my other project. It creates a VPC with the following subnets:

| Purpose   |      AZ1      | AZ2 |AZ3|
|----------|:-------------:|------:|---:|
| Public Subnet with NAT Gateway | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Internal Subnet (Private) | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Node Subnet (Private) | :white_check_mark: | :white_check_mark: | :white_check_mark: |

The stack assumes a high availability requirement in the given region and therefore it straddles across 3 availability zones (AZs). As a result it creates a NAT gateway in each AZ. They are all connected to a single Internet Gateway instance associated with the VPC.

In addition, the stack creates a Bastion host. The Bastion host is part of an autoscaling group for resiliency. It uploads the public key as specified during provisioning. The Bastion host is on the internal subnet, which is private. It connects to AWS SSM endpoint via Internet, allowing 


The project was originally used for creating networking foundation for creating EKS cluster using `eksctl`. Therefore many resources are tagged with Kubernetes well-known labels. However, it can serve as the foundation for any other project on top of a highly available VPC and a bastion host.


## How to use the template

To provision the VPC:
```sh
terraform init
terraform plan
terraform apply
```
The apply output includes the Bastion Host instance ID

## Use case 1. build a private EKS cluster with `eksctl` on top of the VPC

Once applied, the template generates a YAML manifest in `.out/eks.yaml` directory as an input for `eksctl` utility. The output will display this command to run after the network creation.

```
eksctl create cluster -f ./out/eks.yaml
```

The manifest file is generated from a given template, based on subnet IDs created in the apply process. The EKS Cluster creation may take more than 20 minutes, with public endpoint disabled at the end and no access to cluster endpoint from outside of the VPC. Even though `eksctl` configures `kubectl`, you won't be able to connect to the cluster with it.  

To access this cluster from outside of the VPC (e.g. from your laptop), you may use SOCKS5 proxy, with a few additional steps: 

```
BASTION_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --query "SecurityGroups[?contains(GroupName, 'bastion-sg')].GroupId" --output text)

CLUSTER_SECURITY_GROUP_ID=$(aws eks describe-cluster --name private-cluster --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
 
# In Cluster Endpoint's security group, open up port 443 to Bastion host
aws ec2 authorize-security-group-ingress --group-id $CLUSTER_SECURITY_GROUP_ID --source-group $BASTION_SECURITY_GROUP_ID --protocol tcp --port 443
 ```
Test with connecting to Bastion host with ssh i-0750643179667a5b6, assuming .ssh/config file is configured as above. Then we can start an SSH session as a SOCKS5 proxy on the remote host

```
ssh -D 1080 -q -N i-0750643179667a5b6
``` 
You can instruct kubectl to use the SOCKS5 proxy with the following environment variable in a new command terminal:
```
export HTTPS_PROXY=socks5://localhost:1080
 
kubectl get node
```

Read [this post](https://www.digihunch.com/2023/06/connect-kubectl-to-private-kubernetes-cluster-in-eks-and-aks/) for more details on how the connectivity works.

## Use case 2. Create VM for running chat service
The bastion host can serve as any VM that you need for testing. For example, the [chat-service](https://github.com/digihunch/chat-service) project requires an EC2 instance with GPU. You may use this project by specifying parameters:
```sh
export TF_VAR_instance_type=g4dn.xlarge
export AWS_REGION=us-east-1
export TF_VAR_preferred_ami_id=ami-04b70fa74e45c3917
```
Make sure that the preferred AMI ID parameter is an AMI that exists in the specified AWS region. Then run the terraform trilogy and disregard the instructions for other use cases.
