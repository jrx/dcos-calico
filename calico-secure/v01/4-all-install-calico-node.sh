sudo mkdir -p /etc/calico/certs/node

# Certs
sudo ./bootstrap-certs.py calico /etc/calico/certs/node
sudo curl -L http://master.mesos/ca/dcos-ca.crt -o /etc/calico/certs/node/dcos-ca.crt

sudo tee /etc/calico/calico.env <<-'EOF'
ETCD_ENDPOINTS="https://localhost:2379"
ETCD_CERT_DIR="/etc/calico/certs/node"
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
EOF

sudo sed -i "s/DETECT_IP_OUTPUT/$(/opt/mesosphere/bin/detect_ip)/g" /etc/calico/calico.env

sed "s/^/export /g" /etc/calico/calico.env | sudo tee /etc/calico/calico.env.export

sudo tee /etc/systemd/system/dcos-calico-node.service <<-'EOF'
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
 quay.io/calico/node:v2.6.9

ExecStop=-/usr/bin/docker stop calico-node

Restart=always
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

### Notes
# Need /var/run/docker.sock because unable to attach
# Need FELIX_IGNORELOOSERPF

sudo tee /etc/systemd/system/dcos-calico-node.timer <<-'EOF'
[Unit]
Description=Ensure Calico Node is running

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
EOF

sudo systemctl daemon-reload
sudo systemctl enable dcos-calico-node.timer
sudo systemctl restart dcos-calico-node.timer
