# This will be customer-specific, so it's at the top
export CALICO_CIDR=172.16.0.0/16

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

## Env variables
export MASTER_LIST=$(curl -sS master.mesos:8181/exhibitor/v1/cluster/status | python -c 'import sys,json;j=json.loads(sys.stdin.read());print(",".join([y["hostname"]+"=https://"+y["hostname"]+":2380" for y in j]))')

export ETCD_ROOT_DIR=/opt/etcd
export ETCD_DATA_DIR=/var/etcd/data
export ETCD_TLS_CERT=etcd.crt
export ETCD_TLS_KEY=etcd.key
export ETCD_CA_CERT=dcos-ca.crt
export LOCAL_HOSTNAME=$(/opt/mesosphere/bin/detect_ip)
export INITIAL_CLUSTER=${MASTER_LIST}

export CALICO_CNI_PLUGIN_DIR=/opt/calico/plugins
export CALICO_CNI_CONF_DIR=/etc/calico/cni

export CALICO_NODE_IMAGE=quay.io/calico/node:v2.6.9

export ETCD_CERTS_DIR=/etc/etcd/certs
export DOCKER_CLUSTER_CERTS_DIR=/etc/docker/cluster/certs
export CALICO_NODE_CERTS_DIR=/etc/calico/certs/node
export CALICO_CALICOCTL_CERTS_DIR=/etc/calico/certs/calicoctl
export CALICO_CNI_CERTS_DIR=/etc/calico/certs/cni

## Etcd certs
sudo mkdir -p ${ETCD_CERTS_DIR}

sudo ./bootstrap-certs.py etcd ${ETCD_CERTS_DIR}
sudo curl -kL https://master.mesos/ca/dcos-ca.crt -o ${ETCD_CERTS_DIR}/dcos-ca.crt

## Docker certs
sudo mkdir -p ${DOCKER_CLUSTER_CERTS_DIR}

sudo ./bootstrap-certs.py docker-etcd ${DOCKER_CLUSTER_CERTS_DIR}
sudo curl -kL http://master.mesos/ca/dcos-ca.crt -o ${DOCKER_CLUSTER_CERTS_DIR}/dcos-ca.crt

## Calico Node certs
sudo mkdir -p ${CALICO_NODE_CERTS_DIR}

sudo ./bootstrap-certs.py calico ${CALICO_NODE_CERTS_DIR}
sudo curl -kL http://master.mesos/ca/dcos-ca.crt -o ${CALICO_NODE_CERTS_DIR}/dcos-ca.crt

## Calicoctl certs
sudo mkdir -p ${CALICO_CALICOCTL_CERTS_DIR}

sudo ./bootstrap-certs.py calico ${CALICO_CALICOCTL_CERTS_DIR}
sudo curl -kL http://master.mesos/ca/dcos-ca.crt -o ${CALICO_CALICOCTL_CERTS_DIR}/dcos-ca.crt

## CNI Certs
sudo mkdir -p ${CALICO_CNI_CERTS_DIR}

sudo ./bootstrap-certs.py calico ${CALICO_CNI_CERTS_DIR}
sudo curl -kL https://master.mesos/ca/dcos-ca.crt -o ${CALICO_CNI_CERTS_DIR}/dcos-ca.crt

## Other misc. directories
sudo mkdir -p ${ETCD_DATA_DIR}
sudo mkdir -p ${CALICO_CNI_PLUGIN_DIR}
sudo mkdir -p ${CALICO_CNI_CONF_DIR}

#### Env variable files

## etcd environment file
sudo rm -f /etc/etcd/etcd.env
echo "ETCD_ROOT_DIR=${ETCD_ROOT_DIR}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_DATA_DIR=${ETCD_DATA_DIR}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_CERTS_DIR=${ETCD_CERTS_DIR}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_TLS_CERT=${ETCD_TLS_CERT}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_TLS_KEY=${ETCD_TLS_KEY}" | sudo tee -a /etc/etcd/etcd.env
echo "ETCD_CA_CERT=${ETCD_CA_CERT}" | sudo tee -a /etc/etcd/etcd.env
echo "LOCAL_HOSTNAME=${LOCAL_HOSTNAME}" | sudo tee -a /etc/etcd/etcd.env
echo "INITIAL_CLUSTER=${INITIAL_CLUSTER}" | sudo tee -a /etc/etcd/etcd.env

sed "s/^/export /g" /etc/etcd/etcd.env | sudo tee /etc/etcd/etcd.env.export

## calico node environment file
sudo tee /etc/calico/calico.env <<-'EOF'
ETCD_ENDPOINTS="https://localhost:2379"
ETCD_CERT_DIR="ETCD_CERT_DIR_ENV"
ETCD_CONTAINER_CERT_DIR="/etc/certs"
ETCD_CA_CERT_FILE="dcos-ca.crt"
ETCD_CERT_FILE="calico.crt"
ETCD_KEY_FILE="calico.key"
CALICO_NODENAME=""
CALICO_NO_DEFAULT_POOLS=""
CALICO_IP="DETECT_IP_OUTPUT"
CALICO_IP6=""
CALICO_AS=""
CALICO_LIBNETWORK_ENABLED=true
CALICO_NETWORKING_BACKEND=bird
CALICO_DOCKER_IMAGE=CALICO_NODE_IMAGE
EOF

sudo sed -i "s|ETCD_CERT_DIR_ENV|${CALICO_NODE_CERTS_DIR}|g" /etc/calico/calico.env
sudo sed -i "s|CALICO_NODE_IMAGE|${CALICO_NODE_IMAGE}|g" /etc/calico/calico.env
sudo sed -i "s/DETECT_IP_OUTPUT/$(/opt/mesosphere/bin/detect_ip)/g" /etc/calico/calico.env

sed "s/^/export /g" /etc/calico/calico.env | sudo tee /etc/calico/calico.env.export

#### Base systemd files (will be copied to systemd folder later)
sudo tee /etc/etcd/dcos-etcd.service <<-'EOF'
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

# Listen on 0.0.0.0, advertise on 2379/2380
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

sudo tee /etc/etcd/dcos-etcd-proxy.service <<-'EOF'
[Unit]
Description=etcd-proxy
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

# Listen on 0.0.0.0, advertise on 2379/2380
ExecStart=/opt/etcd/etcd --proxy on \
  --data-dir ${ETCD_DATA_DIR} \
  --listen-client-urls https://0.0.0.0:2379 \
  --key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY} \
  --cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --peer-key-file ${ETCD_CERTS_DIR}/${ETCD_TLS_KEY} \
  --peer-cert-file ${ETCD_CERTS_DIR}/${ETCD_TLS_CERT} \
  --trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --peer-trusted-ca-file ${ETCD_CERTS_DIR}/${ETCD_CA_CERT} \
  --client-cert-auth \
  --peer-client-cert-auth \
  --initial-cluster ${INITIAL_CLUSTER}

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/calico/dcos-calico-node.service <<-'EOF'
[Unit]
Description=calico-node
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=/etc/calico/calico.env
ExecStartPre=-/usr/bin/docker rm -f calico-node
ExecStart=/usr/bin/docker run --net=host --privileged \
 --name=calico-node \
 -e NODENAME=${CALICO_NODENAME} \
 -e IP=${CALICO_IP} \
 -e IP6=${CALICO_IP6} \
 -e CALICO_NETWORKING_BACKEND=${CALICO_NETWORKING_BACKEND} \
 -e AS=${CALICO_AS} \
 -e NO_DEFAULT_POOLS=${CALICO_NO_DEFAULT_POOLS} \
 -e CALICO_LIBNETWORK_ENABLED=${CALICO_LIBNETWORK_ENABLED} \
 -e ETCD_ENDPOINTS=${ETCD_ENDPOINTS} \
 -e ETCD_CA_CERT_FILE=${ETCD_CONTAINER_CERT_DIR}/${ETCD_CA_CERT_FILE} \
 -e ETCD_CERT_FILE=${ETCD_CONTAINER_CERT_DIR}/${ETCD_CERT_FILE} \
 -e ETCD_KEY_FILE=${ETCD_CONTAINER_CERT_DIR}/${ETCD_KEY_FILE} \
 -e FELIX_IGNORELOOSERPF=true \
 -v ${ETCD_CERT_DIR}:${ETCD_CONTAINER_CERT_DIR} \
 -v /var/log/calico:/var/log/calico \
 -v /run/docker/plugins:/run/docker/plugins \
 -v /lib/modules:/lib/modules \
 -v /var/run/calico:/var/run/calico \
 -v /var/run/docker.sock:/var/run/docker.sock \
 ${CALICO_DOCKER_IMAGE}

# Need FELIX_IGNORELOOSERPF for DC/OS, see https://github.com/projectcalico/calicoctl/issues/1082
# Need /var/run/docker.sock to connect to host Docker socket from within container

ExecStop=-/usr/bin/docker stop calico-node

Restart=always
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/calico/dcos-calico-node.timer <<-'EOF'
[Unit]
Description=Ensure Calico Node is running

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
EOF

#### Docker daemon configuration (configured to use etcd as cluster store)
# or, if overlay is configured in the systemd unit for docker:
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "cluster-store": "etcd://127.0.0.1:2379",
    "cluster-store-opts": {
        "kv.cacertfile": "DOCKER_CLUSTER_CERTS_DIR/dcos-ca.crt",
        "kv.certfile": "DOCKER_CLUSTER_CERTS_DIR/docker-etcd.crt",
        "kv.keyfile": "DOCKER_CLUSTER_CERTS_DIR/docker-etcd.key"
    }
}
EOF

sudo sed -i "s|DOCKER_CLUSTER_CERTS_DIR|${DOCKER_CLUSTER_CERTS_DIR}|g" /etc/docker/daemon.json

# This should be the preferred one; only switch to above if necessary.  Running this after the above should be fine
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "storage-driver": "overlay",
    "cluster-store": "etcd://127.0.0.1:2379",
    "cluster-store-opts": {
        "kv.cacertfile": "DOCKER_CLUSTER_CERTS_DIR/dcos-ca.crt",
        "kv.certfile": "DOCKER_CLUSTER_CERTS_DIR/docker-etcd.crt",
        "kv.keyfile": "DOCKER_CLUSTER_CERTS_DIR/docker-etcd.key"
    }
}
EOF

sudo sed -i "s|DOCKER_CLUSTER_CERTS_DIR|${DOCKER_CLUSTER_CERTS_DIR}|g" /etc/docker/daemon.json

#### calicoctl config (config for command line tool)

sudo tee /etc/calico/calicoctl.cfg <<-'EOF'
apiVersion: v1
kind: calicoApiConfig
metadata:
spec:
  etcdEndpoints: https://127.0.0.1:2379
  etcdKeyFile: CALICO_CALICOCTL_CERTS_DIR/calico.key
  etcdCertFile: CALICO_CALICOCTL_CERTS_DIR/calico.crt
  etcdCACertFile: CALICO_CALICOCTL_CERTS_DIR/dcos-ca.crt 
EOF

sudo sed -i "s|CALICO_CALICOCTL_CERTS_DIR|${CALICO_CALICOCTL_CERTS_DIR}|g" /etc/calico/calicoctl.cfg

#### CNI Config
sudo tee ${CALICO_CNI_CONF_DIR}/calico.conf <<-'EOF'
{
   "name": "calico",
   "cniVersion": "0.1.0",
   "type": "calico",
   "ipam": {
       "type": "calico-ipam"
   },
   "etcd_endpoints": "https://127.0.0.1:2379",
   "etcd_ca_cert_file": "CALICO_CNI_CERTS_DIR/dcos-ca.crt",
   "etcd_key_file": "CALICO_CNI_CERTS_DIR/calico.key",
   "etcd_cert_file": "CALICO_CNI_CERTS_DIR/calico.crt"
}
EOF

sudo sed -i "s|CALICO_CNI_CERTS_DIR|${CALICO_CNI_CERTS_DIR}|g" ${CALICO_CNI_CONF_DIR}/calico.conf


#### Calico Pool Config (realistically, this is only used once on one node, but it's good to have for reference purposes)
sudo tee /etc/calico/ippool.json <<-'EOF'
  {
    "kind": "ipPool",
    "apiVersion": "v1",
    "metadata": {
      "cidr": "CALICO_CIDR"
    },
    "spec": {
      "nat-outgoing": true,
      "ipip": {
        "enabled": true,
        "mode": "cross-subnet"
      }
    }
  }
EOF

sudo sed -i "s|CALICO_CIDR|${CALICO_CIDR}|g" /etc/calico/ippool.json
