#!/bin/bash
oc apply -f install/cluster-operator/020-RoleBinding-strimzi-cluster-operator.yaml -n $1
oc apply -f install/cluster-operator/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n $1
oc apply -f install/cluster-operator/032-RoleBinding-strimzi-cluster-operator-topic-operator-delegation.yaml -n $1
