$rg = "way-aks-rg"
$location = "eastus"
$aksName = "way-east-aks"
$acrName = "wayaks"
$vnet = "way-east-vnet"
$vnetCidr = "10.0.0.0/16"
$nodeSubnet = "10.0.0.0/20"
$ingressSubnet = '10.0.16.0/24'
$privateEndpointSubnet = '10.0.17.0/24'
$podCidr = '192.168.0.0/16'
$serviceCidr = '10.1.0.0/16'
$dockerBridgeCidr = '172.17.0.1/16'
$dnsIp = '10.1.0.10'
$image = "simple-api:latest"
$ingressNamespace = "ingress-basic"
$systemPoolName = "systempool"
$systemPoolTaint = "CriticalAddonsOnly=true:NoSchedule"

# Create rg, acr, and vnet
az group create -n $rg -l $location
az acr create -n $acrName -g $rg --sku Basic --admin-enabled true --location $location
az network vnet create -g $rg -n $vnet --address-prefix $vnetCidr --location $location
az network vnet subnet create -g $rg --vnet-name $vnet -n NodeSubnet --address-prefix $nodeSubnet
az network vnet subnet create -g $rg --vnet-name $vnet -n IngressSubnet --address-prefix $ingressSubnet
az network vnet subnet create -g $rg --vnet-name $vnet -n PrivateEndpointSubnet --address-prefix $privateEndpointSubnet

$subnetIdPrefix = "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rg/providers/Microsoft.Network/virtualNetworks/$vnet/subnets"

# Create AKS
# az aks create -g $rg -n $aksName --enable-managed-identity --node-count 1 --location $location `
#     --attach-acr $acrName --enable-cluster-autoscaler --min-count 1 --max-count 3 `
#     --enable-addons monitoring --enable-msi-auth-for-monitoring  --generate-ssh-keys `
#     --enable-addons ingress-appgw --appgw-subnet-id $subnetIdPrefix/IngressSubnet --appgw-name gateway `
#     --enable-aad --enable-azure-rbac --vnet-subnet-id $subnetIdPrefix/NodeSubnet --pod-cidr $podCidr `
#     --network-plugin kubenet --service-cidr $serviceCidr --dns-service-ip $dnsIp --docker-bridge-address $dockerBridgeCidr

# Apply RBAC for AD user
# $userId = az ad signed-in-user show --query id -o tsv
# az role assignment create --assignee $userId --role "Azure Kubernetes Service RBAC Cluster Admin" --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$rg/providers/Microsoft.ContainerService/managedClusters/$aksName

az aks create -g $rg -n $aksName --enable-managed-identity --node-count 1 --location $location `
    --attach-acr $acrName --nodepool-name $systemPoolName --enable-cluster-autoscaler --min-count 1 --max-count 3 `
    --enable-addons monitoring --enable-msi-auth-for-monitoring  --generate-ssh-keys `
    --vnet-subnet-id $subnetIdPrefix/NodeSubnet --pod-cidr $podCidr `
    --network-plugin kubenet --service-cidr $serviceCidr --dns-service-ip $dnsIp --docker-bridge-address $dockerBridgeCidr

az aks nodepool update -g $rg -n $systemPoolName --cluster-name $aksName --node-taints $systemPoolTaint

az aks nodepool add -g $rg -n userpool --cluster-name $aksName --node-count 1 --node-vm-size Standard_DS2_v2

# Get AKS credentials
az aks get-credentials -g $rg -n $aksName --overwrite-existing

# Push the test image
az acr login -n $acrName
docker push "$acrName.azurecr.io/$image"

# Create nginx ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx `
  --create-namespace `
  --namespace $ingressNamespace `
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
