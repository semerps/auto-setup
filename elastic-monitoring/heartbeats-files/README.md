# Elastic Heartbeat Configuration Files

This folder contains configuration files for Elastic Heartbeat, a tool used for monitoring services and systems. There are different configurations for various namespaces. Below is an example configuration for the "uzmarBilisim" namespace.

## 'uzmarBilisim' Configuration

### heartbeat-config.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: heartbeat-config
  namespace: semerp
data:
  heartbeat.yml: |
    heartbeat.monitors:
    - type: http
      schedule: '@every 5m'
      urls:
        - http://semerp-demo.semerp.svc.cluster.local:8090/sem
      data_stream:
        dataset: "heartbeat"
        namespace: "uzmar-bilisim"
      id: semerp-demo
      name: SEMERP_DEMO (UZMAR BİLİŞİM)
    - type: tcp
      schedule: '@every 5m'
      hosts: ["mssql.semerp.svc.cluster.local"]
      ports: [1433]
      data_stream:
        dataset: "heartbeat"
        namespace: "uzmar-bilisim"
      id: mssql-bilisim
      name: MSSQL (UZMAR BİLİŞİM)
    - type: tcp
      schedule: '@every 5m'
      hosts: ["rabbitmq.semerp.svc.cluster.local"]
      ports: [5672]
      data_stream:
        dataset: "heartbeat"
        namespace: "uzmar-bilisim"
      id: rabbitmq-bilisim
      name: RabbitMQ (UZMAR BİLİŞİM) 
    output.elasticsearch:
      hosts: ['http://elastic.semerp.com:9202']
      username: elastic
      password: sem2023.*
    http.enabled: true
    http.host: 0.0.0.0
    setup.kibana:
      host: http://kibana.semerp.com:5601
      username: elastic
      password: sem2023.*

```


### heartbeat-config.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: heartbeat-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: heartbeat
  template:
    metadata:
      labels:
        app: heartbeat
    spec:
      containers:
      - name: heartbeat
        image: docker.elastic.co/beats/heartbeat:8.4.1
        args:
        - -e
        - -E
        - heartbeat.config.monitoring.enabled=false
        - -E
        - heartbeat.config.output.elasticsearch.enabled=true
        - -E
        - heartbeat.config.input.type=http
        - -E
        - heartbeat.config.inputs.0.schedule=@every 120s
        - -E
        - heartbeat.config.inputs.0.urls.0=http://semerp-demo.semerp.svc.cluster.local:8090
        volumeMounts:
        - name: heartbeat-config-volume
          mountPath: /usr/share/heartbeat/heartbeat.yml
          subPath: heartbeat.yml
      volumes:
      - name: heartbeat-config-volume
        configMap:
          name: heartbeat-config
          items:
          - key: heartbeat.yml
            path: heartbeat.yml

```

# Applying Configuration

To apply this configuration in your Kubernetes cluster with the semerp namespace, you can use the following command:

```bash
kubectl apply -n semerp -f heartbeat-config.yaml
kubectl apply -n semerp -f heartbeat-deployment.yaml
```

Make sure you have the necessary permissions and that your Kubernetes context is correctly set to the desired cluster.

Remember to adjust the configuration according to your specific needs and namespaces for the other folders (_**uzmar**_, _**asfat**_, and _**asfatTest**_) if they differ from the "_**uzmarBilisim**_" example provided here.

