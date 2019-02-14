#!/bin/bash

## Deployment to strimzi
oc login -u system:admin
oc apply -f prometheus-operator/prometheus-crd.yml -n strimzi
oc process -f prometheus-operator/prometheus-operator.yml -p NAMESPACE=strimzi -p KAFKA_SERVICE_TEAM=aims | oc apply -f -

## Monitoring stack deployment to kafka cluster
oc login -u developer
oc create -f prometheus-operator/additional-scrape-configs.yml -n kafka-1
oc process -f prometheus-operator/prometheus.yml -p NAMESPACE=kafka-1 -p KAFKA_SERVICE_TEAM=aims | oc apply -f -
oc process -f prometheus-operator/kafka-servicemonitor.yml -p NAMESPACE=kafka-1 -p KAFKA_CLUSTER_NAME=my-cluster -p KAFKA_SERVICE_TEAM=aims -p ENDPOINT_PORT=metrics | oc create -f -

oc apply -f prometheus-operator/burrow/burrow-deployment.yml
oc apply -f metrics/examples/grafana/kubernetes.yaml
