Quick steps to install prometheus operator
===

* Steps to install sample application which exposes prometheus metrics on port 8080 and monitor it using prometheus operator natively.
```bash
oc apply -f prometheus-crd.yml
customresourcedefinition "prometheusrules.monitoring.coreos.com" created
customresourcedefinition "servicemonitors.monitoring.coreos.com" created
customresourcedefinition "prometheuses.monitoring.coreos.com" created
customresourcedefinition "alertmanagers.monitoring.coreos.com" created
```

* Additinal scrape configuration to scrape K8s objects, cluster roles are added to **prometheus-operator.yml** to support this configuration. This will eventual be delegated to K8s (CAE) admin team.

```bash
oc create secret generic additional-scrape-configs --from-file=prometheus-additional.yml --dry-run -oyaml > additional-scrape-configs.yml

oc create -f additional-scrape-configs.yml
```

* Create burrow side car
```bash
oc apply -f ./burrow/burrow-deployment.yml
service "burrow" created
configmap "burrow-config" created
deployment "burrow" created
```

* Create service monitors for kafka

First by creating prometheus instance & then servicemonitor to monitor kafka
```bash
oc process -f prometheus-operator.yml -p NAMESPACE=kafka-1 -p KAFKA_SERVICE_TEAM=aims | oc create -f -
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

oc process -f kafka-servicemonitor.yml -p NAMESPACE=kafka-1 -p  \
KAFKA_CLUSTER_NAME=my-cluster -p KAFKA_SERVICE_TEAM=aims -p \
ENDPOINT_PORT=metrics | oc create -f -
servicemonitor "kafka" created
service "kafka" created
```

* Validation step to check whether kafka metrics are picked up by prometheus operator servicemonitor CRD

```bash
oc get secrets  prometheus-prometheus -ojson | jq -r '.data["prometheus.yaml"]' | base64 -D | grep my-cluster

```
* Port forward the prometheus console service port and visualize metrics being scraped
```bash
oc port-forward prometheus-prometheus-0 9090:9090
```


### Reference:
* (https://github.com/dichque/prometheus-operator)[Prometheus Operator]
