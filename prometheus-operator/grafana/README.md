## Steps for deploying grafana manually

### Create configmaps
```
kubectl apply -f grafana-config.yaml
kubectl apply -f grafana-datasrc.yaml
kubectl apply -f grafana-dashsrc.yaml
kubectl create cm kafka-dashboards --from-file=dashboards/
```

## Create deployment
kubectl apply -f grafana-deploy.yaml
