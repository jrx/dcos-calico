source env.export


## Scriptlet used to generate certs using DC/OS CA
tee bootstrap-certs.py <<-'EOF'
#!/opt/mesosphere/bin/python

import sys
sys.path.append('/opt/mesosphere/lib/python3.6/site-packages')

from dcos_internal_utils import bootstrap

if len(sys.argv) == 1:
    print("Usage: ./bootstrap-certs.py <CN> <PATH> | ./bootstrap-certs.py etcd /var/lib/dcos/etcd/certs")
    sys.exit(1)

b = bootstrap.Bootstrapper(bootstrap.parse_args())
b.read_agent_secrets()

cn = sys.argv[1]
location = sys.argv[2]

keyfile = location + '/' + cn + '.key'
crtfile = location + '/' + cn + '.crt'

b.ensure_key_certificate(cn, keyfile, crtfile, service_account='dcos_bootstrap_agent')
EOF
chmod +x bootstrap-certs.py

sudo mkdir -p /etc/calico/certs/kubernetes
# sudo /home/centos/bootstrap-certs.py kubernetes-etcd /etc/calico/certs/kubernetes
sudo /home/centos/bootstrap-certs.py kubernetes-client /etc/calico/certs/kubernetes
sudo curl -Lk https://master.mesos/ca/dcos-ca.crt -o /etc/calico/certs/kubernetes/dcos-ca.crt


sudo tee ${CALICO_CNI_CONF_DIR}/${KUBERNETES_CNI_CONF_FILE} <<-'EOF'
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
           "k8s_client_key": "/etc/calico/certs/kubernetes/kubernetes-client.key",
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

sudo /bin/cp ${CALICO_CNI_CONF_DIR}/${KUBERNETES_CNI_CONF_FILE} /opt/mesosphere/etc/dcos/network/cni/
# Do not actually need to restart, as this isn't used by Mesos, only by K8s
# sudo systemctl restart dcos-mesos-slave*

# We do need it to persist across upgrades, though

# grep MESOS_NETWORK_CNI_PLUGINS_DIR /opt/mesosphere/etc/mesos-slave-common | sudo tee -a /var/lib/dcos/mesos-slave-common
# sudo sed -i '/MESOS_NETWORK_CNI_PLUGINS_DIR/s|$|:CALICO_CNI_PLUGIN_DIR|g' /var/lib/dcos/mesos-slave-common
# sudo sed -i "s|CALICO_CNI_PLUGIN_DIR|${CALICO_CNI_PLUGIN_DIR}|g" /var/lib/dcos/mesos-slave-common

## Plugin conf
sudo mkdir -p /etc/systemd/system/dcos-mesos-slave.service.d
# We can do both dcos-mesos-slave and dcos-mesos-slave-common on all nodes, safely; only the relevant one will be used by the corresponding systemd unit
# We use a systemd override to copy the conf from custom location into default MESOS_NETWORK_CNI_CONFIG_DIR
sudo tee /etc/systemd/system/dcos-mesos-slave.service.d/kubernetes-calico-conf-override.conf <<-'EOF'
[Service]
ExecStartPre=/bin/cp CALICO_CNI_CONF_DIR/KUBERNETES_CNI_CONF_FILE /opt/mesosphere/etc/dcos/network/cni/
EOF

sudo sed -i "s|CALICO_CNI_CONF_DIR|${CALICO_CNI_CONF_DIR}|g" /etc/systemd/system/dcos-mesos-slave.service.d/kubernetes-calico-conf-override.conf
sudo sed -i "s|KUBERNETES_CNI_CONF_FILE|${KUBERNETES_CNI_CONF_FILE}|g" /etc/systemd/system/dcos-mesos-slave.service.d/kubernetes-calico-conf-override.conf

sudo mkdir -p /etc/systemd/system/dcos-mesos-slave-public.service.d
# /etc/systemd/system/dcos-mesos-slave.service.d/override.conf
sudo tee /etc/systemd/system/dcos-mesos-slave-public.service.d/kubernetes-calico-conf-override.conf <<-'EOF'
[Service]
ExecStartPre=/bin/cp CALICO_CNI_CONF_DIR/KUBERNETES_CNI_CONF_FILE /opt/mesosphere/etc/dcos/network/cni/
EOF

sudo sed -i "s|CALICO_CNI_CONF_DIR|${CALICO_CNI_CONF_DIR}|g" /etc/systemd/system/dcos-mesos-slave-public.service.d/kubernetes-calico-conf-override.conf
sudo sed -i "s|KUBERNETES_CNI_CONF_FILE|${KUBERNETES_CNI_CONF_FILE}|g" /etc/systemd/system/dcos-mesos-slave-public.service.d/kubernetes-calico-conf-override.conf

# Need to reload, but don't restart services cause we already manually copied stuff
sudo systemctl daemon-reload