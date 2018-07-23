dcos package install dcos-enterprise-cli --cli --yes
dcos security org service-accounts keypair kubernetes-private-key.pem kubernetes-public-key.pem
dcos security org service-accounts create -p kubernetes-public-key.pem -d 'Kubernetes service account' kubernetes
dcos security secrets create-sa-secret --strict kubernetes-private-key.pem kubernetes kubernetes/sa
dcos security org groups add_user superusers kubernetes
dcos package install kubernetes --cli --yes

curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.9.7/bin/linux/amd64/kubectl

chmod +x kubectl

sudo mv kubectl /usr/local/bin/

dcos kubernetes kubeconfig

# Insecure install
bash 1a-env.export.sh ; bash 1c-prereqs-systemd.sh ; bash 1do-prereqs-conf.sh; bash 2-package-install.sh ; bash 3o-enable-masters.sh

bash 1a-env.export.sh ; bash 1c-prereqs-systemd.sh ; bash 1do-prereqs-conf.sh; bash 2-package-install.sh ; bash 5o-enable-agents.sh 
bash 6o-kubernetes.sh

# Secure install
# master
bash 1a-env.export.sh; bash 1b-prereqs-certs.sh; bash 1c-prereqs-systemd.sh; bash 1d-prereqs-conf.sh
bash 2-package-install.sh
bash 3-enable-masters.sh

# slave
bash 1a-env.export.sh; bash 1b-prereqs-certs.sh; bash 1c-prereqs-systemd.sh; bash 1d-prereqs-conf.sh
bash 2-package-install.sh


sudo mkdir -p /etc/calico/certs/kubernetes
sudo /home/centos/bootstrap-certs.py kubernetes-etcd /etc/calico/certs/kubernetes
sudo /home/centos/bootstrap-certs.py kubernetes-client /etc/calico/certs/kubernetes
sudo curl -Lk https://master.mesos/ca/dcos-ca.crt -o /etc/calico/certs/kubernetes/dcos-ca.crt




sudo tee /opt/mesosphere/etc/dcos/network/cni/cni.conflist <<-'EOF'
   {
     "cniVersion": "0.3.0",
     "name": "kube-cni",
     "plugins": [
       {
         "type": "calico",
         "etcd_endpoints": "http://localhost:62379",
         "ipam": {
           "type": "calico-ipam"
         },
         "policy": {
           "type": "k8s",
           "k8s_api_root": "https://apiserver.kubernetes.l4lb.thisdcos.directory:6443",
           "k8s_client_certificate": "/etc/calico/certs/kubernetes/kubernetes-client.crt",
           "k8s_client_key": /etc/calico/certs/kubernetes/kubernetes-client.key",
           "k8s_certificate_authority": "/etc/calico/certs/kubernetes/dcos-ca.crt"
         }
       },
       {
         "type": "portmap",
         "capabilities": { "portMappings": true},
         "snat": true
       }
      ]
   }
EOF

sudo systemctl restart dcos-mesos-slave*


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

sudo rm /etc/systemd/system/dcos-mesos-slave*/override.conf
sudo rm /opt/mesosphere/etc/dcos/network/cni/calico.conf
sudo systemctl daemon-reload; sudo systemctl restart dcos-mesos-slave*

# Re-add
sudo cp /etc/calico/cni/calico.conf /opt/mesosphere/etc/dcos/network/cni/
sudo systemctl restart dcos-mesos-slave*

# re-remove
sudo rm /opt/mesosphere/etc/dcos/network/cni/calico.conf
sudo systemctl restart dcos-mesos-slave*