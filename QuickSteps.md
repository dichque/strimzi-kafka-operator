# Kafka on OpenShift using Strimzi Operators
---
Dated: 12th November 2018<br>
[Jagadish Nagarajaiah](mailto:jaganaga@cisco.com)

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
oc new-project strimzi --display-name="Kafka Operator"
oc project strimzi
sed -i '' 's/namespace: .*/namespace: strimzi/' install/cluster-operator/*RoleBinding*.yaml
oc apply -f install/cluster-operator -n strimzi
oc apply -f examples/templates/cluster-operator -n strimzi

```

## Configuring Operator to manage a project
### Create the project and assign necessary roles. In this case developer has been granted admin privileges on the new project.
```
oc new-project kafka-1 --display-name="Kafka Demo Cluster 1"
oc adm policy add-role-to-user admin developer -n kafka-1
```

### Update the rolebindings
First ensure service account, role and rolebindings w.r.t strimzi operator are updated
```
sed -i '' 's/namespace: .*/namespace: strimzi/' install/cluster-operator/*RoleBinding*.yaml
```
Grant strimzi service account to have access on new project *kafka-1*
```
oc apply -f install/cluster-operator/020-RoleBinding-strimzi-cluster-operator.yaml -n kafka-1
oc apply -f install/cluster-operator/031-RoleBinding-strimzi-cluster-operator-entity-operator-delegation.yaml -n kafka-1
oc apply -f install/cluster-operator/032-RoleBinding-strimzi-cluster-operator-topic-operator-delegation.yaml -n kafka-1
```

### Configure the operator to manage the new namespace aka project by updating *STRIMZI_NAMESPACE*
This is done by updating *STRIMZI_NAMESPACE* variable in *install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml*
```
      - name: strimzi-cluster-operator
        image: strimzi/cluster-operator:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: STRIMZI_NAMESPACE
          value: kafka-1
```

```
oc apply -f install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml -n strimzi
```
or
```
oc set env deployment/strimzi-cluster-operator STRIMZI_NAMESPACE=strimzi,kafka-1 -n strimzi
```

## Granting developer permissions to create cluster
```
oc apply -f install/strimzi-admin/010-ClusterRole-strimzi-admin.yaml
```
In openshift, you could also probably do, once *strimzi-admin* cluster role is created.
```
oc adm policy add-cluster-role-to-user strimzi-admin developer
```
or in k8s kubectl apply following yaml
```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: strimzi-admin-binding
subjects:
  - kind: User
    name: developer
roleRef:
  kind: ClusterRole
  name: StrimziAdmin
  apiGroup: rbac.authorization.k8s.io
```
Notes:
* [strimzi-admin.yaml](https://gist.githubusercontent.com/scholzj/614065a081ad92669c32f45894510c8c/raw/253b43b194e1d288755dd2bedb79e7bfef669d7c/strimzi-admin.yaml)


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


## Sample publishing and consuming
* Create test topic
```bash
oc apply -f examples/topic/kafka-topic.yaml
```

* Producer

```
oc run kafka-producer -ti --image=strimzi/kafka:latest --rm=true --restart=Never -- bin/kafka-console-producer.sh --broker-list my-cluster-kafka-bootstrap:9092 --topic my-topic
```
* Consumer


```
oc run kafka-consumer -ti --image=strimzi/kafka:latest --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
```

## Monitoring
* Prerequiste
Kafka cluster should be up and running with prometheus exporter and following kafka2.0 metrics config
``` yaml
#https://github.com/prometheus/jmx_exporter/blob/master/example_configs/kafka-2_0_0.yml
metrics:
  # Inspired by config from Kafka 2.0.0 example rules:
  # https://github.com/prometheus/jmx_exporter/blob/master/example_configs/kafka-2_0_0.yml
  lowercaseOutputName: true
  rules:
  # Special cases and very specific rules
  - pattern : kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
    name: kafka_server_$1_$2
    type: GAUGE
    labels:
      clientId: "$3"
      topic: "$4"
      partition: "$5"
  - pattern : kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
    name: kafka_server_$1_$2
    type: GAUGE
    labels:
      clientId: "$3"
      broker: "$4:$5"
  # Some percent metrics use MeanRate attribute
  # Ex) kafka.server<type=(KafkaRequestHandlerPool), name=(RequestHandlerAvgIdlePercent)><>MeanRate
  - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>MeanRate
    name: kafka_$1_$2_$3_percent
    type: GAUGE
  # Generic gauges for percents
  - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>Value
    name: kafka_$1_$2_$3_percent
    type: GAUGE
  - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*, (.+)=(.+)><>Value
    name: kafka_$1_$2_$3_percent
    type: GAUGE
    labels:
      "$4": "$5"
  # Generic per-second counters with 0-2 key/value pairs
  - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+), (.+)=(.+)><>Count
    name: kafka_$1_$2_$3_total
    type: COUNTER
    labels:
      "$4": "$5"
      "$6": "$7"
  - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+)><>Count
    name: kafka_$1_$2_$3_total
    type: COUNTER
    labels:
      "$4": "$5"
  - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*><>Count
    name: kafka_$1_$2_$3_total
    type: COUNTER
  # Generic gauges with 0-2 key/value pairs
  - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Value
    name: kafka_$1_$2_$3
    type: GAUGE
    labels:
      "$4": "$5"
      "$6": "$7"
  - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Value
    name: kafka_$1_$2_$3
    type: GAUGE
    labels:
      "$4": "$5"
  - pattern: kafka.(\w+)<type=(.+), name=(.+)><>Value
    name: kafka_$1_$2_$3
    type: GAUGE
  # Emulate Prometheus 'Summary' metrics for the exported 'Histogram's.
  # Note that these are missing the '_sum' metric!
  - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Count
    name: kafka_$1_$2_$3_count
    type: COUNTER
    labels:
      "$4": "$5"
      "$6": "$7"
  - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*), (.+)=(.+)><>(\d+)thPercentile
    name: kafka_$1_$2_$3
    type: GAUGE
    labels:
      "$4": "$5"
      "$6": "$7"
      quantile: "0.$8"
  - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Count
    name: kafka_$1_$2_$3_count
    type: COUNTER
    labels:
      "$4": "$5"
  - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*)><>(\d+)thPercentile
    name: kafka_$1_$2_$3
    type: GAUGE
    labels:
      "$4": "$5"
      quantile: "0.$6"
  - pattern: kafka.(\w+)<type=(.+), name=(.+)><>Count
    name: kafka_$1_$2_$3_count
    type: COUNTER
  - pattern: kafka.(\w+)<type=(.+), name=(.+)><>(\d+)thPercentile
    name: kafka_$1_$2_$3
    type: GAUGE
    labels:
      quantile: "0.$4"
zookeeper:
replicas: 3
readinessProbe:
  initialDelaySeconds: 15
  timeoutSeconds: 5
livenessProbe:
  initialDelaySeconds: 15
  timeoutSeconds: 5
storage:
  type: persistent-claim
  size: 100Mi
  deleteClaim: false
metrics:
  # Inspired by Zookeeper rules
  # https://github.com/prometheus/jmx_exporter/blob/master/example_configs/zookeeper.yaml
  lowercaseOutputName: true
  rules:
  # replicated Zookeeper
  - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+)><>(\\w+)"
    name: "zookeeper_$2"
  - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+), name1=replica.(\\d+)><>(\\w+)"
    name: "zookeeper_$3"
    labels:
      replicaId: "$2"
  - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+), name1=replica.(\\d+), name2=(\\w+)><>(\\w+)"
    name: "zookeeper_$4"
    labels:
      replicaId: "$2"
      memberType: "$3"
  - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+), name1=replica.(\\d+), name2=(\\w+), name3=(\\w+)><>(\\w+)"
    name: "zookeeper_$4_$5"
    labels:
      replicaId: "$2"
      memberType: "$3"
  # standalone Zookeeper
  - pattern: "org.apache.ZooKeeperService<name0=StandaloneServer_port(\\d+)><>(\\w+)"
    name: "zookeeper_$2"
  - pattern: "org.apache.ZooKeeperService<name0=StandaloneServer_port(\\d+), name1=(InMemoryDataTree)><>(\\w+)"
    name: "zookeeper_$2_$3"
entityOperator:
topicOperator: {}
userOperator: {}
```
* Install prometheus
```
oc apply -f metrics/examples/prometheus/kubernetes.yaml
## Ensure namespace field for service account is correct
```

* Install and configure Grafana
```
oc apply -f metrics/examples/grafana/kubernetes.yaml
oc port-forward <grafana-pod> 3000:3000
```
Access the grafana web ui at [http://localhost:3000](Grafana local) with user admin and password admin. Setup prometheus datasource *http://prometheus:9090* and import sample zookeeper and kafka dashboards

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

* Publishing & Subscribing
```
oc run kafka-producer -ti --image=containers.cisco.com/jaganaga/kafka:0.9.0-kafka-2.2.1 --rm=true --restart=Never -- bin/kafka-console-producer.sh --broker-list my-cluster-kafka-bootstrap:9092 --topic my-topic

oc run kafka-consumer -ti --image=strimzi/kafka:0.9.0-kafka-2.2.1 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic my-topic --from-beginning
```