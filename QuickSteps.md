## Introduction
Here are quick steps to get the operator setup and run on minishift

## Minishift Installation
```
brew install docker-machine-driver-xhyve
sudo chown root:wheel $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
sudo chmod u+s $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
brew cask install --force minishift
minishift  start --profile strimzi-demo --network-nameserver "8.8.8.8" --vm-driver xhyve

## Add oc from minishift to PATH
export PATH=$HOME/.minishift/cache/oc/v3.11.0/darwin/oc:$PATH
```

## Strimzi Operator Installation
```
hub clone git@github.com:dichque/strimzi-kafka-operator.git
oc login -u system:admin
oc new-project strimzi-home --display-name="Kafka Operator"
oc project strimzi-home
sed -i '' 's/namespace: .*/namespace: strimzi-home/' install/cluster-operator/*RoleBinding*.yaml
oc apply -f install/cluster-operator -n strimzi-home
oc apply -f examples/templates/cluster-operator -n strimzi-home

```

## Configuring Operator to manage a project
### Create the project and assign necessary roles. In this case developer has been granted admin privileges on the new project.
```
oc new-project kafka-deploy1 --display-name="Kafka Demo Cluster 1"
oc adm policy add-role-to-user admin developer -n kafka-deploy1
```

### Update the rolebindings
```
sed -i '' 's/namespace: .*/namespace: my-namespace/' install/cluster-operator/*RoleBinding*.yaml
oc apply -f install/cluster-operator/020-RoleBinding-strimzi-cluster-operator.yaml -n kafka-deploy1
oc apply -f install/cluster-operator/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n kafka-deploy1
oc apply -f install/cluster-operator/032-RoleBinding-strimzi-cluster-operator-topic-operator-delegation.yaml -n kafka-deploy1
```

### Configure the operator to manage the new namespace aka project by updating *STRIMZI_NAMESPACE*
This is done by updating *STRIMZI_NAMESPACE* variable in *install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml*
```
      - name: strimzi-cluster-operator
        image: strimzi/cluster-operator:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: STRIMZI_NAMESPACE
          value: kafka-deploy1
```

```
oc apply -f install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml -n strimzi-home
```
or
```
oc set env deployment/strimzi-cluster-operator STRIMZI_NAMESPACE=kafka-deploy1
```
## Deploying
Now that project where we intend to deploy kafka cluster is setup and is watched by the operator, we can submit a CRD to provision the cluster
```
cat examples/kafka/kafka-ephemeral.yaml
apiVersion: kafka.strimzi.io/v1alpha1
kind: Kafka
metadata:
  name: kafka-1
spec:
  kafka:
    replicas: 2
    listeners:
      plain: {}
      tls: {}
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
    storage:
      type: ephemeral
  zookeeper:
    replicas: 2
    storage:
      type: ephemeral
  entityOperator:
    topicOperator: {}
    userOperator: {}
```
```
oc apply -f examples/kafka/kafka-ephemeral.yaml
```

## Granting developer user to create cluster
```
Refer: apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: StrimziAdmin
rules:
- apiGroups:
  - "kafka.strimzi.io"
  resources:
  - kafkas
  - kafkaconnects
  - kafkaconnects2is
  - kafkausers
  - kafkatopics
  verbs:
  - get
  - list
  - watch
  - create
  - delete
  - patch
  - update
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: StrimziAdminBinding
subjects:
  - kind: User
    name: developer
roleRef:
  kind: ClusterRole
  name: StrimziAdmin
  apiGroup: rbac.authorization.k8s.io

```
In openshift, you could also probably do, once *StrimziAdmin* cluster role is created.
```
oc adm policy add-cluster-role-to-user StrimziAdmin developer
```
Notes: 
* [https://gist.githubusercontent.com/scholzj/614065a081ad92669c32f45894510c8c/raw/253b43b194e1d288755dd2bedb79e7bfef669d7c/strimzi-admin.yaml](https://gist.githubusercontent.com/scholzj/614065a081ad92669c32f45894510c8c/raw/253b43b194e1d288755dd2bedb79e7bfef669d7c/strimzi-admin.yaml)

## Build Strimzi Operator & Docker Image build
Strimzi operator is built using java, the images are
```
21:02 $ jenv versions
  system
* 1.8 (set by /Users/jaganaga/WA/repo/kube/kafka/strimzi-kafka-operator/.java-version)
  1.8.0.181
  11
  11.0
  11.0.1
  openjdk64-11
  oracle64-1.8.0.181
  oracle64-11.0.1

21:02 $ jenv local
1.8
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_181.jdk/Contents/Home
export MVN_ARGS="-DskipTests -DskipITs"
make docker_build
```