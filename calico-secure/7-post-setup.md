docker network create --driver calico --ipam-driver calico-ipam calico

```json
{
  "id": "/calico-ucr-task",
  "cmd": "tail -f /dev/null",
  "constraints": [
    [
      "hostname",
      "UNIQUE"
    ]
  ],
  "container": {
    "type": "MESOS",
    "volumes": []
  },
  "cpus": 0.1,
  "instances": 5,
  "mem": 32,
  "networks": [
    {
      "name": "calico",
      "mode": "container"
    }
  ]
}
```

```json
{
  "id": "/calico-ucr-alpine",
  "cmd": "tail -f /dev/null",
  "constraints": [
    [
      "hostname",
      "UNIQUE"
    ]
  ],
  "container": {
    "type": "MESOS",
    "volumes": [],
    "docker": {
      "image": "alpine"
    }
  },
  "cpus": 0.1,
  "instances": 5,
  "mem": 32,
  "networks": [
    {
      "name": "calico",
      "mode": "container"
    }
  ]
}
```

```json
{
  "id": "/calico-docker-alpine",
  "cmd": "tail -f /dev/null",
  "constraints": [
    [
      "hostname",
      "UNIQUE"
    ]
  ],
  "container": {
    "type": "DOCKER",
    "volumes": [],
    "docker": {
      "image": "alpine"
    }
  },
  "cpus": 0.1,
  "instances": 5,
  "mem": 32,
  "networks": [
    {
      "name": "calico",
      "mode": "container"
    }
  ]
}
```


```bash
>ips
for task in $(dcos task | grep calico-ucr | awk '{print $5}')
do dcos task exec ${task} hostname -i | grep -v variable >> ips
done

for task in $(dcos task | grep calico-ucr | awk '{print $5}')
do
  for i in $(cat ips)
  do
  echo "Pinging ${i} from ${task}..."
  dcos task exec ${task} ping -c2 -W1 $i | grep transmitted
  done
done
```