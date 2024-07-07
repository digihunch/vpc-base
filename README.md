# VPC-base

I use this project is to provision the networking stack as the infrastructure foundation for my other project. It creates a VPC with the following subnets:

| Purpose   |      AZ1      | AZ2 |AZ3|
|----------|:-------------:|------:|---:|
| Public Subnet with NAT Gateway | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Internal Service Subnet (Private) | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Data Subnet (Private) | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Node Subnet (Private) | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Pod Subnet (Private) | :white_check_mark: | :white_check_mark: | :white_check_mark: |

The stack assumes a high availability requirement in the given region and therefore it straddles across 3 availability zones (AZs). As a result it creates a NAT gateway in each AZ. They are all connected to a single Internet Gateway instance associated with the VPC.

In addition, the stack creates a Bastion host. The Bastion host is part of an autoscaling group for resiliency. It uploads the public key as specified during provisioning. The Bastion host is on the internal service subnet, which is private. It connects to AWS SSM endpoint via Internet, allowing 


The project was originally used for creating networking foundation for creating EKS cluster using `eksctl`. Therefore many resources are tagged with Kubernetes well-known labels. However, it can serve as the foundation for any other project on top of a highly available VPC and a bastion host.


## How to use the template

Simply play the Terraform trilogy:
```sh
terraform init
terraform plan
terraform apply

# The apply output includes
# 1. Bastion Host instance ID
# 2. Bastion Host Security Group ID
# 3. Next set of commands to set environment variable
```
The output displays a few additional commands for the next steps for the EKS cluster usecase.

## Use case 1. Create a private EKS cluster with Fargate using `eksctl`

The original use case of this project is to create a private EKS cluster from the [cloudkube](https://github.com/digihunch/cloudkube) project. Once the `apply` step is completed, run the command given on the screen to set environment variables. Then use them to populate the template file:

```sh
# Load the environment variables, then create private cluster using eksctl
envsubst < private-cluster.yaml.tmpl | tee | eksctl create cluster -f -
```

Cluster creation may take more than 20 minutes, with public endpoint disabled at the end and no access to cluster endpoint from outside of the VPC. 

To access the cluster, you may use SOCKS5 proxy to connect from outside of VPC: 

```
BASTION_SECURITY_GROUP_ID=$(terraform output -raw bastion_sg_id)
CLUSTER_SECURITY_GROUP_ID=$(aws eks describe-cluster --name private-cluster --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
 
# In Cluster Endpoint's security group, open up port 443 to Bastion host
aws ec2 authorize-security-group-ingress --group-id $CLUSTER_SECURITY_GROUP_ID --source-group $BASTION_SECURITY_GROUP_ID --protocol tcp --port 443
 
# Test with connecting to Bastion host with ssh i-0750643179667a5b6, assuming .ssh/config file is configured as above. From the bastion host, you can test:
# curl -k https://EC5405EE1846F19F9F61ED28FB12A6A9.sk1.us-west-2.eks.amazonaws.com/api  
# if you get an HTTP response, even an error code 403, the bastion host has TCP connectivity to cluster endpoint
 
# then we can start an SSH session as a SOCKS5 proxy on the remote host
ssh -D 1080 -q -N i-0750643179667a5b6
 
# add > /dev/null 2>&1 & to push it to background, or use ctrl+z after running the command
# to validate that the SOCKS5 proxy is working, you can run the same curl command with a proxy parameter:
# curl -k https://EC5405EE1846F19F9F61ED28FB12A6A9.sk1.us-west-2.eks.amazonaws.com/api --proxy socks5://localhost:1080
 
# you can instruct kubectl to use the SOCKS5 proxy with the following environment variable
export HTTPS_PROXY=socks5://localhost:1080
 
kubectl get node
```

Review [this post](https://www.digihunch.com/2023/06/connect-kubectl-to-private-kubernetes-cluster-in-eks-and-aks/) for more details on how the connectivity work in this model.

## Use case 2. Create VM for running chat service
The bastion host can serve as any VM that you need for testing. For example, the [chat-service](https://github.com/digihunch/chat-service) project requires an EC2 instance with GPU. You may use this project by specifying parameters:
```sh
export TF_VAR_instance_type=g4dn.xlarge
export AWS_REGION=us-east-1
export TF_VAR_preferred_ami_id=ami-04b70fa74e45c3917
```
Make sure that the preferred AMI ID parameter is an AMI that exists in the specified AWS region. Then run the terraform trilogy and disregard the instructions for other use cases.