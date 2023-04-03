# DataStax Helm Charts Repository

## cass-operator

```bash
helm repo add datastax https://datastax.github.io/charts
helm repo update

# Helm 2
helm install datastax/cass-operator

# Helm 3
helm install cass-operator datastax/cass-operator
```


## Pulsar Admin Console

See [pulsar-admin-console](charts/pulsar-admin-console/README.md)