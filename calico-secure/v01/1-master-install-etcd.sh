# ETCD v3, using v2 API
# Generate certs
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
sudo mkdir -p /opt/etcd/
sudo mkdir -p /etc/etcd/certs
sudo mkdir -p /var/etcd/data

# Certs
sudo ./bootstrap-certs.py etcd /etc/etcd/certs
sudo curl -L http://master.mesos/ca/dcos-ca.crt -o /etc/etcd/certs/dcos-ca.crt

# Install etcd
curl -LO https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz

sudo tar -xzvf etcd-v3.3.5-linux-amd64.tar.gz -C /opt/etcd --strip-components=1

# Create env file
sudo rm -f/etc/etcd/etcd.env
echo "ETCD_DATA_DIR=/var/etcd/data" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_CERTS_DIR=/etc/etcd/certs" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_TLS_CERT=etcd.crt" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_TLS_KEY=etcd.key" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_CA_CERT=dcos-ca.crt" | sudo tee -a /etc/etcd/etcd.env
echo "LOCAL_HOSTNAME=$(/opt/mesosphere/bin/detect_ip)" | sudo tee -a /etc/etcd/etcd.env
echo "INITIAL_CLUSTER=$(curl -sS master.mesos:8181/exhibitor/v1/cluster/status | python -c 'import sys,json;j=json.loads(sys.stdin.read());print(",".join([y["hostname"]+"=https://"+y["hostname"]+":2380" for y in j]))')" | sudo tee -a /etc/etcd/etcd.env

sed "s/^/export /g" /etc/etcd/etcd.env | sudo tee /etc/etcd/etcd.env.export

# Listen on 0.0.0.0, but don't advertise on 0.0.0.0
# Create etcd service
sudo tee /etc/systemd/system/dcos-etcd.service <<-'EOF'
[Unit]
Description=etcd
Documentation=https://github.com/coreos/etcd
Conflicts=etcd.service
Conflicts=etcd2.service

[Service]
Type=notify
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0

EnvironmentFile=/etc/etcd/etcd.env

ExecStart=/opt/etcd/etcd --name ${LOCAL_HOSTNAME} \
  --data-dir ${ETCD_DATA_DIR} \
  --listen-client-urls https://0.0.0.0:2379 \
  --advertise-client-urls https://${LOCAL_HOSTNAME}:2379 \
  --listen-peer-urls https://0.0.0.0:2380 \
  --initial-advertise-peer-urls https://${LOCAL_HOSTNAME}:2380 \
  --initial-cluster ${INITIAL_CLUSTER} \
  --initial-cluster-token tkn \
  --initial-cluster-state new \
  --client-cert-auth \
  --trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY} \
  --peer-client-cert-auth \
  --peer-trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --peer-cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --peer-key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY}

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable dcos-etcd.service
sudo systemctl restart dcos-etcd.service


sudo ETCDCTL_API=2 /opt/etcd/etcdctl \
  --endpoints https://localhost:2379 \
  --key-file /etc/etcd/certs/etcd.key \
  --cert-file /etc/etcd/certs/etcd.crt \
  --ca-file /etc/etcd/certs/dcos-ca.crt \
  cluster-health 
