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

dcos security cluster ca newcert --cn "calico-kube-controller" --host "localhost" --json > calico-kube-controller.json
cat calico-kube-controller.json | python -c 'import sys,json;j=sys.stdin.read();print(json.loads(j)["certificate"])' | grep -v '^$' > calico-kube-controller.crt
cat calico-kube-controller.json | python -c 'import sys,json;j=sys.stdin.read();print(json.loads(j)["private_key"])' | grep -v '^$' > calico-kube-controller.key
rm calico-kube-controller.json
dcos security cluster ca cacert > dcos-ca.crt

kubectl create secret generic calico-etcd-certs \
  --namespace=kube-system \
  --from-file=./calico-kube-controller.crt \
  --from-file=./calico-kube-controller.key \
  --from-file=./dcos-ca.crt

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
          # Make sure to pin this to your desired version - 0.3.0 doesn't support tls 1.2
          # image: calico/kube-policy-controller:v0.3.0
          image: quay.io/calico/kube-controllers:v1.0.4
          env:  
            - name: ETCD_ENDPOINTS
              value: "https://localhost:62379"
            - name: CONFIGURE_ETC_HOSTS
              value: "true"
            - name: ETCD_CA_CERT_FILE
              value: "/calico-secrets/dcos-ca.crt"
            - name: ETCD_KEY_FILE
              value: "/calico-secrets/calico-kube-controller.key"
            - name: ETCD_CERT_FILE
              value: "/calico-secrets/calico-kube-controller.crt"
          volumeMounts:
            - name: etcd-certs
              mountPath: /calico-secrets
              readOnly: true
      volumes:
        - name: etcd-certs
          secret:
            secretName: calico-etcd-certs
EOF

kubectl apply -f policy_controller.yaml
