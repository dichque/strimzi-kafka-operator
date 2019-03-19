#!/bin/bash

## Prometheus operator deployment to strimzi ns
oc login -u system:admin
oc apply -f prometheus-operator/prometheus-crd.yml -n strimzi
oc process -f prometheus-operator/prometheus-operator.yml -p NAMESPACE=strimzi -p KAFKA_SERVICE_TEAM=aims | oc apply -f -

## Prometheus stack deployment to kafka ns
# oc login -u developer
oc create -f prometheus-operator/additional-scrape-configs.yml -n kafka-1
oc apply -f prometheus-operator/alertmanager-secret.yaml -n kafka-1
oc process -f prometheus-operator/prometheus.yml -p NAMESPACE=kafka-1 -p KAFKA_SERVICE_TEAM=aims -p PROMETHEUS_MEMORY=800Mi | oc apply -f -
oc process -f prometheus-operator/kafka-servicemonitor.yml -p NAMESPACE=kafka-1 -p KAFKA_CLUSTER_NAME=my-cluster -p KAFKA_SERVICE_TEAM=aims -p ENDPOINT_PORT=metrics | oc create -f -

# Burrow
oc apply -f prometheus-operator/burrow/burrow-deployment.yml -n kafka-1

# Grafana stack
oc apply -f prometheus-operator/grafana/kafka-dashboards.yaml -n kafka-1
oc apply -f prometheus-operator/grafana/grafana-config.yaml -n kafka-1
oc apply -f prometheus-operator/grafana/grafana-datasrc.yaml -n kafka-1
oc apply -f prometheus-operator/grafana/grafana-dashsrc.yaml -n kafka-1
oc apply -f prometheus-operator/grafana/grafana-deploy.yaml -n kafka-1
