#!/bin/bash
oc login -u system:admin
oc new-project strimzi --display-name="Kafka Operator"
sed -i '' 's/namespace: .*/namespace: strimzi/' install/cluster-operator/*RoleBinding*.yaml
oc apply -f install/cluster-operator -n strimzi
oc apply -f examples/templates/cluster-operator -n strimzi


oc new-project kafka-1 --display-name="Kafka Demo Cluster 1"
oc adm policy add-role-to-user admin developer -n kafka-1
./svc-rolebinding.sh kafka-1

oc set env deployment/strimzi-cluster-operator STRIMZI_NAMESPACE=strimzi,kafka-1 -n strimzi

oc apply -f install/strimzi-admin/010-ClusterRole-strimzi-admin.yaml
oc adm policy add-cluster-role-to-user strimzi-admin developer
