# Get calico plugin
sudo mkdir -p /var/lib/dcos/calico/cni
sudo mkdir -p /var/lib/dcos/calico/certs
sudo mkdir -p /var/lib/dcos/calico/cni-config
sudo curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.11.5/calico -o /var/lib/dcos/calico/cni/calico
sudo curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.11.5/calico-ipam -o /var/lib/dcos/calico/cni/calico-ipam
sudo chmod +x /var/lib/dcos/calico/cni/calico
sudo chmod +x /var/lib/dcos/calico/cni/calico-ipam

# Certs
sudo ./bootstrap-certs.py calico /var/lib/dcos/calico/certs
sudo curl -L http://master.mesos/ca/dcos-ca.crt -o /var/lib/dcos/calico/certs/dcos-ca.crt

# Write config
# https://docs.projectcalico.org/v2.6/reference/cni-plugin/configuration

sudo tee /var/lib/dcos/calico/cni-config/calico.conf <<-'EOF'
{
   "name": "calico",
   "cniVersion": "0.1.0",
   "type": "calico",
   "ipam": {
       "type": "calico-ipam"
   },
   "etcd_endpoints": "https://127.0.0.1:2379",
   "etcd_ca_cert_file": "/var/lib/dcos/calico/certs/dcos-ca.crt",
   "etcd_key_file": "/var/lib/dcos/calico/certs/calico.key",
   "etcd_cert_file": "/var/lib/dcos/calico/certs/calico.crt"
}
EOF

grep MESOS_NETWORK_CNI_PLUGINS_DIR /opt/mesosphere/etc/mesos-slave-common | sudo tee -a /var/lib/dcos/mesos-slave-common
sudo sed -i '/MESOS_NETWORK_CNI_PLUGINS_DIR/s|$|:/var/lib/dcos/calico/cni|' /var/lib/dcos/mesos-slave-common
sudo ln -s /var/lib/dcos/calico/cni-config/calico.conf /opt/mesosphere/etc/dcos/network/cni/calico.conf

## Restart
sudo systemctl restart dcos-mesos-slave*
