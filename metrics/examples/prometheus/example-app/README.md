Quick steps to install prometheus operator
===

* Steps to install sample application which exposes prometheus metrics on port 8080 and monitor it using prometheus operator natively.
```bash
oc apply -f prometheus-crd.yml
customresourcedefinition "prometheusrules.monitoring.coreos.com" created
customresourcedefinition "servicemonitors.monitoring.coreos.com" created
customresourcedefinition "prometheuses.monitoring.coreos.com" created
customresourcedefinition "alertmanagers.monitoring.coreos.com" created

oc apply -f example-app-deployment.
deployment "example-app" created

oc process -f prometheus-operator.yml -p NAMESPACE=kafka-1 | oc create -f -
rolebinding "prometheus-operator" created
role "prometheus-operator" created
deployment "prometheus-operator" created
serviceaccount "prometheus-operator" created
prometheus "prometheus" created
service "prometheus" created
serviceaccount "prometheus" created
role "prometheus" created
rolebinding "prometheus" created
route "prometheus" created

oc process -f example-app-servicemonitor.yml -p NAMESPACE=kafka-1 -p  \
FUSE_SERVICE_NAME=example-app -p FUSE_SERVICE_TEAM=fuse -p \
ENDPOINT_PORT=web | oc create -f -
servicemonitor "example-app" created
service "example-app" created

```

* Validation step to check whether example-app metrics are picked up by prometheus operator servicemonitor CRD

```bash
oc get secrets  prometheus-prometheus -ojson | jq -r '.data["prometheus.yaml"]' | base64 -D | grep example-app
- job_name: kafka-1/example-app/0
    regex: example-app

```
* Port forward the prometheus console service port and visualize metrics being scraped
```bash
oc port-forward <prometheus-port> 9090:9090
```
### Reference:
* (https://github.com/dichque/prometheus-operator)[Prometheus Operator]
