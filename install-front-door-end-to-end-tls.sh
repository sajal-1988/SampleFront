# Install kubectl
az aks install-cli --only-show-errors

# Get AKS credentials
az aks get-credentials \
  --admin \
  --name $clusterName \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --only-show-errors

# Check if the cluster is private or not
private=$(az aks show --name $clusterName \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --query apiServerAccessProfile.enablePrivateCluster \
  --output tsv)
  
# Create values.yaml file for Istio
echo "Creating values.yaml file for Istio..."
cat <<EOF >valuesIstio.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: default 
  components:
    ingressGateways:
      - name: istio-ingressgateway
        enabled: true
        k8s:
          serviceAnnotations:
            service.beta.kubernetes.io/azure-load-balancer-internal: "true"
EOF
 
# Download and install Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.26.0 sh -
# Add istioctl to PATH
export PATH="$PATH:$(pwd)/istio-1.26.0/bin"
 
# Make sure namespace exists
kubectl create namespace istio-system || true
 
# Install Istio using the values file
istioctl install -f valuesIstio.yaml --skip-confirmation || {
  echo "Istio installation failed!"
  exit 1
}

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh -s
chmod 700 get_helm.sh
./get_helm.sh &>/dev/null

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kiali https://kiali.org/helm-charts
helm repo add jetstack https://charts.jetstack.io

# Update Helm repos
helm repo update

# Install Kiali
#if [[ "$installKiali" == "true" ]]; then
  echo "Installing Kiali..."
  helm install \
    --set cr.create=true \
    --set cr.namespace=istio-system \
    --set cr.spec.auth.strategy="anonymous" \
    --namespace kiali-operator \
    --create-namespace \
    kiali-operator \
    kiali/kiali-operator
#fi

# Install Prometheus
if [[ "$installPrometheusAndGrafana" == "true" ]]; then
  echo "Installing Prometheus and Grafana..."
  helm install prometheus prometheus-community/kube-prometheus-stack \
    --create-namespace \
    --namespace istio-system \
	--set grafana.enabled=true \
    --set grafana.defaultDashboardsEnabled=true \
    --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
fi



# Create an ingress resource for the application
echo "Label namesspace"
kubectl label namespace default istio-injection=enabled
