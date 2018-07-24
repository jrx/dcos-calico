dcos package install dcos-enterprise-cli --cli --yes
dcos security org service-accounts keypair kubernetes-private-key.pem kubernetes-public-key.pem
dcos security org service-accounts create -p kubernetes-public-key.pem -d 'Kubernetes service account' kubernetes
dcos security secrets create-sa-secret --strict kubernetes-private-key.pem kubernetes kubernetes/sa
dcos security org groups add_user superusers kubernetes
dcos package install kubernetes --cli --yes

curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.9.7/bin/linux/amd64/kubectl

chmod +x kubectl

sudo mv kubectl /usr/local/bin/

####

dcos kubernetes kubeconfig

tee policy_controller.yaml <<-'EOF'
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: calico-kube-controller
  namespace: kube-system
  labels:
    k8s-app: calico-kube-controller
spec:
  replicas: 1
  template:
    metadata:
      name: calico-kube-controller
      namespace: kube-system
      labels:
        k8s-app: calico-kube-controller
    spec:
      hostNetwork: true
      containers:
        - name: calico-kube-controller
          # Make sure to pin this to your desired version.
          image: calico/kube-policy-controller:v0.3.0
          env:  
            - name: ETCD_ENDPOINTS
              value: "http://localhost:62379"
            - name: CONFIGURE_ETC_HOSTS
              value: "true"
EOF

kubectl apply -f policy_controller.yaml