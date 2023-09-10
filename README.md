# Performance testing monitoring solution
## About

The solution is used to store and visualize performance test result.  
It is based on ELK-stack and Grafana:

*  [Filebeat](https://www.elastic.co/beats/filebeat) running on a load generator machine reads the result of each request and sends it to a Logstash
*  [Logstash](https://www.elastic.co/logstash) parses the result of each request and stores it in Elasticsearch
*  [Elasticsearch](https://www.elastic.co/elasticsearch/) is used to store the result of each request
*  [Grafana](https://grafana.com/) visualizes test results
*  [Kibana](https://www.elastic.co/kibana) is an additional tool used to visualize and view raw data stored in Elasticsearch
*  [haproxy](https://www.haproxy.org/) is used to unload HTTPS to Grafana and Kibana

```mermaid
sequenceDiagram
    box darkolivegreen Load Injector Machine
    participant Load generation tool
    participant Test result file
    participant Filebeat
    end
    box lightslategrey Performance Monitoring Solution
    participant Logstash
    participant Elasticsearch
    participant Grafana
    end
    actor Human
    Load generation tool->>Test result file: save request result
    Filebeat->>Test result file: read request result
    Filebeat->>Logstash: ship request results
    Note over Logstash: parse test data
    Logstash->>Elasticsearch: store parsed test data
    Grafana->>Elasticsearch: get test data
    Human->>Grafana: visualize test data
```

## How to run

Set all required environment variables in `.\.env` file and execute `docker compose up -d`

### Environment variables

1. `ELK_VERSION`: version of ELK stack
1. `ES_HOST`: Elasticsearch instance hostname used in internal docker network
1. `ES_PORT`: Elasticsearch instance port  used in internal docker network
1. `LOGSTASH_PORT`: Logstash instance port  used in internal docker network
1. `KIBANA_PORT`: Kibana instance port  used in internal docker network
1. `EXTERNAL_IP`: IP of the server running the solution: Logstash, Elasticsearch, Grafana, Kibana
1. `EXTERNAL_HOST`: hostname of the server running the solution: Logstash, Elasticsearch, Grafana, Kibana
1. `USE_EXTERNAL_CERT`: if set to true Haproxy uses a certificate stored at `./secrets/external/external.pem`. If set to `false` and `./secrets/external/external.pem` doesn't exist, the setup step generates a self-signed certificate.
1. `ELASTIC_PASSWORD`: password for `elastic` Elasticsearch [built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html)
1. `KIBANA_PASSWORD`: password for `kibana_system` Elasticsearch [built-in user](https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html)
1. `LOGSTASH_USER`: username for Elasticsearch user used by Logstash to push test data
1. `LOGSTASH_PASSWORD`: password for Elasticsearch user used by Logstash to push test data
1. `ELASTIC_GRAFANA_USER`: username for Elasticsearch user used by Grafana to read test data indices
1. `ELASTIC_GRAFANA_PASSWORD`: password for Elasticsearch user used by Grafana to read test data indices
1. `GRAFANA_USER`: username for a Grafana admin user
1. `GRAFANA_PASSWORD`: password for a Grafana admin user
1. `ES_HEAP`: Elasticsearch instance heap space size
1. `LOGSTASH_HEAP`: Logstash instance heap space size

## Loading sample test data set

By default, the solution doesn't contain any test data.  
To load the default sample test data set:

1. Excute `sudo chmod go-w filebeat/filebeat.yml` to ensure `filebeat\filebeat.yml` has write permission only for the owner
1. run `docker compose -f docker-compose.filebeat.yml up -d` command from project root folder. 
It starts the Filebeat container that pushes test data from `sample-data-set` folder to the solution.

## Grafana dashboards

![Aggregated metrics](https://user-images.githubusercontent.com/22715888/266862000-90a3befd-0e6b-41e7-9d20-020506feaea9.png)
![Comparison dashboard](https://user-images.githubusercontent.com/22715888/266862041-61a10298-b3db-454d-a37c-6d5206ceb4d9.png)
![Timeline dashboard](https://user-images.githubusercontent.com/22715888/266862085-ca397680-a09d-4333-875b-61c42e891eea.png)
![Errors dashboard](https://user-images.githubusercontent.com/22715888/266862152-4334652c-47c3-430d-b2e3-17197e948051.png)
