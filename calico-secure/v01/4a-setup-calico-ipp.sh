# On one node:
tee calico-pool.json <<-'EOF'
  {
    "kind": "ipPool",
    "apiVersion": "v1",
    "metadata": {
      "cidr": "172.16.0.0/16"
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

sudo calicoctl get ipps -o json > calico-pool-backup.json
sudo calicoctl delete ipps 192.168.0.0/16
sudo calicoctl apply -f calico-pool.json