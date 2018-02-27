## Calico policies

To keep the rule design simple and powerful, each application should get its own profile and respective role named after the application. Afterwards a whitelist approach can be configured, so that each profile contains rules to explicitly allow a specific role access. Further restrictions inside the cluster network and the internet should be configured using CIDR notation.

### Deploy Containers for Testing

- Allow Marathon to start containers as `root` for easy testing

```
# Create permission to start containers as root
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:root \
-d '{"description":"Allows Linux user root to execute tasks"}' \
-H 'Content-Type: application/json'
# Grant permissions to Marathon
curl -X PUT -k \
-H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:mesos:master:task:user:root/users/dcos_marathon/create
```

- Start simple Nginx server

```json
{
  "id": "/nginx-ucr",
  "user": "root",
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "nginx"
    }
  },
  "cpus": 0.1,
  "instances": 1,
  "mem": 128,
  "networks": [
    {
      "name": "calico",
      "mode": "container",
      "labels": {
        "role": "nginx-ucr"
      }
    }
  ]
}
```

- Start a container `test-allow` that should be allowed to curl the Nginx server below

```json
{
  "id": "/test-allow",
  "user": "root",
  "cmd": "while true; do echo 'Access to Nginx: Allowed'; sleep 60; done",
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "centos"
    }
  },
  "cpus": 0.1,
  "instances": 1,
  "mem": 128,
  "networks": [
    {
      "name": "calico",
      "mode": "container",
      "labels": {
        "role": "test-allow"
      }
    }
  ]
}
```

- Start a second container `test-deny` that should NOT be allowed to curl the Nginx server

```json
{
  "id": "/test-deny",
  "user": "root",
  "cmd": "while true; do echo 'Access to Nginx: Denied'; sleep 60; done",
  "container": {
    "type": "MESOS",
    "docker": {
      "image": "centos"
    }
  },
  "cpus": 0.1,
  "instances": 1,
  "mem": 128,
  "networks": [
    {
      "name": "calico",
      "mode": "container",
      "labels": {
        "role": "test-deny"
      }
    }
  ]
}
```

- Setup profile for `nginx-ucr` to be only accessible from `/test-allow`.

```yaml
calicoctl apply -f - <<EOF
apiVersion: v1
kind: policy
metadata:
  name: allow-nginx-ucr-tcp-80
spec:
  selector: role == 'nginx-ucr'
  ingress:
  - action: allow
    protocol: tcp
    source:
      selector: role == 'test-allow'
    destination:
      ports:
      - 80
  egress:
  - action: allow
EOF
```

- We jump into the container `test-allow` and try to curl the Nginx Server. This should work fine:

```
$ dcos task exec test-allow curl nginx-ucr.marathon.containerip.dcos.thisdcos.directory
Overwriting environment variable 'LIBPROCESS_IP'
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   122k      0 --:--:-- --:--:-- --:--:--  149k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

- If we jump into the second container `test-deny` and try to do the same. We should not be able to etablish an connection:

```
$ dcos task exec test-deny curl nginx-ucr.marathon.containerip.dcos.thisdcos.directory
Overwriting environment variable 'LIBPROCESS_IP'
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:13 --:--:--     0
```
