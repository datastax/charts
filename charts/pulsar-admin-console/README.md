# Admin Console for Apache Pulsar

This is the chart for the [Datastax Pulsar Admin Console](https://github.com/datastax/pulsar-admin-console/).

## Managing Pulsar using Admin Console

```
helm repo add datastax https://datastax.github.io/charts
helm repo update
helm install pulsar-admin-console datastax/pulsar-admin-console
```

### Connect to the Pulsar cluster

The console needs the Apache Pulsar cluster coordinates:

```
config:
  server_config:
    pulsar_url: "http://pulsar-broker:8080"    
    websocket_url: "ws://pulsar-proxy-ws:8000"
    function_worker_url: "http://pulsar-function:6750"
```

If the cluster is protected by authentication, you'll need to provide the Pulsar admin token to use. (only jwt supported).
The recommended way is to mount a super user token in the console container.
```
additionalVolumes:
    - name: token-superuser
        secret:
            secretName: token-superuser

additionalVolumeMounts:
    - name: token-superuser
      mountPath: /pulsar-token

config:
    server_config:
        token_path: /pulsar-token
```

Alternatively, you can specify the token in the values via the `config.server_config.admin_token` (not recommended for production environment).

Note that the client will receive the token after being authenticated in the admin console.

The above configuration is for the admin API calls.
To authenticate the Pulsar client, you'll need to specify the private key path or a secret used to generate a valid JWT token.

```
additionalVolumes:
    - name: token-private-key
        secret:
            secretName: token-private-key
additionalVolumeMounts:
    - name: token-private-key
      mountPath: /pulsar-private-key
config:
    server_config:
        token_options:
            private_key_path: /pulsar-private-key
            algorithm: RS256
```


### Admin Console authentication

By default, the admin console has authentication disabled. 
There are multiple ways to setup authentication. The configuration follows the `config.auth_mode` value.
See more [here](https://github.com/datastax/pulsar-admin-console/#auth-modes).

#### User/Password
You can set a fixed user credentials directly in the values file.

```
config:
  auth_mode: "user"
  server_config:
    user_auth:
      username: "admin"
      password: "mypass"
```

#### Kubernetes secret

You can instruct the console to looking for user credentials in the Kubernetes secrets.

```
config:
    auth_mode: "k8s"
```
  

When `k8s` authentication mode is enabled, the admin console gets the users from Kubernetes secrets that start with `dashboard-user-` in the same namespace where it is deployed. The text that follows the prefix is the username. For example, for a user `admin` you need to have a secret `dashboard-user-admin`. The secret data must have a key named `password` with the base-64 encoded password. The following command will create a secret for a user `admin` with a password of `password`:

```
kubectl create secret generic dashboard-user-admin --from-literal=password=password
```

You can create multiple users for the admin console by creating multiple secrets. To change the password for a user, delete the secret then recreate it with a new password:

```
kubectl delete secret dashboard-user-admin
kubectl create secret generic dashboard-user-admin --from-literal=password=newpassword
```

For convenience, the chart is able to create an initial user for the admin console with the following settings:

```
createUserSecret:
  enabled: true
  user: admin
  password: mypassword
```


#### KeyCloak (OpenID Connect)

When using the openidconnect auth mode, the auth call needs to go to the Provider's server `identity_provider_url`.
The following example assumes that:
- the KeyCloak instance is reachable at `http://keycloak-service:80`
- the realm is `pulsar`
- there's a client id configured called `pulsar-admin-console`

```
config:
    auth_mode: "openidconnect"
    # The client id used when authenticating with keycloak
    oauth_client_id: "pulsar-admin-console"
    oauth2:
        identity_provider_url: "http://keycloak-service:80"
        token_endpoint: "/realms/pulsar/protocol/openid-connect/token"
```


### Accessing Admin Console on your local machine
To access the Pulsar admin console on your local machine on port 8080:

```
kubectl port-forward $(kubectl get pods -l app.kubernetes.io/name=pulsar-admin-console -o jsonpath='{.items[0].metadata.name}') 8080:8080
```

### Accessing Admin Console from cloud provider
To access Pulsar admin console from a cloud provider, the chart supports [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/). Your Kubernetes cluster must have a running Ingress controller (ex Nginx, Traefik, etc.).

Set these values to configure the Ingress for the admin console:

```
ingress:
    enabled: true
    hosts:
    - pulsar-ui.example.com
```

### Secure the admin console with TLS
To setup https you'll need to enable the `config.ssl` section.

```
config:
    server_config:
        ssl:
            enabled: true
```

Automatically the service port will switch from 8080 to 8443.

### Advanced configuration
For a more detailed explanation, you can look at the [Configuration Reference](https://github.com/datastax/pulsar-admin-console/#configuration-reference).