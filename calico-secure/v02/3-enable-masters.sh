


####### etcd
# Install, enable, and start etcd systemd unit (will hang until it's run on all masters)
sudo cp /etc/etcd/dcos-etcd.service /etc/systemd/system/dcos-etcd.service

sudo systemctl daemon-reload
sudo systemctl enable dcos-etcd.service
sudo systemctl restart dcos-etcd.service

# Validate it's running (etcd must be running on all masters prior to this working)
sudo ETCDCTL_API=2 /opt/etcd/etcdctl \
  --endpoints https://localhost:2379 \
  --key-file /etc/etcd/certs/etcd.key \
  --cert-file /etc/etcd/certs/etcd.crt \
  --ca-file /etc/etcd/certs/dcos-ca.crt \
  cluster-health 

####### Docker cluster store
# Get docker to pick up the new config
# !!! If this fails, you may have to remove the 'overlay' line from /etc/docker/daemon.json - it doesn't like redundant configurations
# sudo sed -i "/storage-driver/d" /etc/docker/daemon.json
sudo systemctl restart docker

# Validate
sudo docker info | grep -i cluster

####### Calico node (not strictly necessary on masters, but a good idea, I think)
sudo cp /etc/calico/dcos-calico-node.service /etc/systemd/system/dcos-calico-node.service
sudo cp /etc/calico/dcos-calico-node.timer /etc/systemd/system/dcos-calico-node.timer

sudo systemctl daemon-reload
sudo systemctl enable dcos-calico-node.service
sudo systemctl restart dcos-calico-node.service

sudo systemctl enable dcos-calico-node.timer
sudo systemctl restart dcos-calico-node.timer

# Check status
sleep 15
sudo calicoctl node status