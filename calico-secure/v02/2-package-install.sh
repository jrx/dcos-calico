# Do all stuff in a tmp directory, doesn't matter where
export ETCD_ROOT_DIR=/opt/etcd
export CALICO_CNI_PLUGIN_DIR=/opt/calico/plugins
export CALICO_NODE_IMAGE=quay.io/calico/node:v2.6.9

## Install etcd
# Verify directory is set
echo ${ETCD_ROOT_DIR}
sudo mkdir -p ${ETCD_ROOT_DIR}

curl -LO https://github.com/coreos/etcd/releases/download/v3.3.5/etcd-v3.3.5-linux-amd64.tar.gz
sudo tar -xzvf etcd-v3.3.5-linux-amd64.tar.gz -C ${ETCD_ROOT_DIR} --strip-components=1

## install in /usr/bin; will require root access to use because of cert configuration
sudo curl -L https://github.com/projectcalico/calicoctl/releases/download/v1.6.4/calicoctl -o /usr/bin/calicoctl
sudo chmod +x /usr/bin/calicoctl

## Install Calico plugins
echo ${CALICO_CNI_PLUGIN_DIR}

sudo curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.11.5/calico -o ${CALICO_CNI_PLUGIN_DIR}/calico
sudo curl -L https://github.com/projectcalico/cni-plugin/releases/download/v1.11.5/calico-ipam -o ${CALICO_CNI_PLUGIN_DIR}/calico-ipam
sudo chmod +x ${CALICO_CNI_PLUGIN_DIR}/calico
sudo chmod +x ${CALICO_CNI_PLUGIN_DIR}/calico-ipam

ls ${CALICO_CNI_PLUGIN_DIR}

## Download Docker image for Calico node
sudo docker pull ${CALICO_NODE_IMAGE}