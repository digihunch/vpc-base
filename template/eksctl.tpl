apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: private-cluster
  region: ${eks_region}
  version: "1.30"
privateCluster:
  enabled: true 
  additionalEndpointServices:
  - "cloudformation"
  - "autoscaling"
  - "logs"
vpc:
  id: "${vpc_id}"
  subnets:
    private:
%{ for az, subnetid in nodesubnets ~}
      ${az}:
        id: "${subnetid}"
%{ endfor }
fargateProfiles:
  - name: fp-default
    selectors:
      - namespace: default
      - namespace: kube-system
#managedNodeGroups:
#  - name: managed-ng-1
#    instanceType: m5.large 
#    desiredCapacity: 2
#    minSize: 2
#    maxSize: 2
#    privateNetworking: true
#    volumeSize: 80
#    ssh:
#      allow: true
#      enableSsm: true