# Install calicoctl
sudo curl -L https://github.com/projectcalico/calicoctl/releases/download/v1.6.4/calicoctl -o /usr/bin/calicoctl
sudo chmod +x /usr/bin/calicoctl

sudo mkdir -p /etc/calico/certs/calicoctl

# Certs
sudo ./bootstrap-certs.py calico /etc/calico/certs/calicoctl
sudo curl -L http://master.mesos/ca/dcos-ca.crt -o /etc/calico/certs/calicoctl/dcos-ca.crt

sudo tee /etc/calico/calicoctl.cfg <<-'EOF'
apiVersion: v1
kind: calicoApiConfig
metadata:
spec:
  etcdEndpoints: https://127.0.0.1:2379
  etcdKeyFile: /etc/calico/certs/calicoctl/calico.key
  etcdCertFile: /etc/calico/certs/calicoctl/calico.crt
  etcdCACertFile: /etc/calico/certs/calicoctl/dcos-ca.crt 
EOF

sudo calicoctl node status

