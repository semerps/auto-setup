#!/bin/sh

#ZIP dosyasının indirme bağlantısı
apt update
apt install -y unzip
unzip files/setup.zip -d files
CURRENT_DIR=$(pwd)
namespace="semerp"
ip_address=$(ip -4 addr show eth0 | grep -oP "(?<=inet ).*(?=/)")
#<!------------------Fonksiyon Listesi----------------------------

echo "Bulunduğunuz dizin: $CURRENT_DIR"

# Fonksiyon tanımı
print_message() {
  echo "\n##############################################################################\n"
  echo $1
  echo "\n##############################################################################\n"
}

wait_for_pod() {
  local namespace=$1
  local deployment=$2

  while true; do
    if microk8s.kubectl -n $namespace get deployment $deployment &> /dev/null; then
      replicas=$(microk8s.kubectl -n $namespace get deployment $deployment -o jsonpath='{.status.replicas}')
      available=$(microk8s.kubectl -n $namespace get deployment $deployment -o jsonpath='{.status.availableReplicas}')
      if [ "$replicas" = "$available" ]; then

        print_message "$deployment All replicas are available"
        break
      else
        print_message "$deployment Waiting for all replicas to become available..."
      fi
    else
      print_message "$deployment Deployment not found"
    fi
    sleep 10
  done
}

#<!----------------Elastic Kurulumu----------------------------
print_message "Elastic sunucusu sizin için kuruluyor..."
apt install jq
sed -i "s|ELASTIC_SEARCH_PATH|$CURRENT_DIR/files/elasticsearch|g" files/elasticsearch/deployment.yaml
microk8s.kubectl apply -f files/elasticsearch/ -n $namespace
wait_for_pod $namespace elasticsearch
wait_for_pod $namespace kibana
response_elk_token=$(curl -s -X POST "elasticsearch.$namespace.svc.cluster.local:9200/_security/api_key" -H "Content-Type: application/json" -d'
{
  "name": "nlm-api-key",
  "role_descriptors": {
    "my_role": {
      "cluster": ["all"],
      "index": [
        {
          "names": ["*"],
          "privileges": ["all"]
        }
      ]
    }
  }
}')

elk_api_key=$(echo $response_elk_token | jq -r '.api_key')
elk_api_key_id=$(echo $response_elk_token | jq -r '.id')

print_message "Elastic sunucusu kurulumu tamamlandı."
#----------------Elastic Kurulumu----------------------------!>

#<!-----------------Mongo Kurulumu----------------------------
print_message "Mongo sunucusu sizin için kuruluyor..."
read -p "Lütfen MongoDB için kullanıcı adı giriniz: " mongodb_username
read -p "Lütfen MongoDB için şifre giriniz: " mongodb_password
sed -i "s|MONGODB_PATH|$CURRENT_DIR/files/mongo|g" files/mongo/storage.yaml
sed -i "s|mongodb_username|$mongodb_username|g" files/mongo/deployment.yaml
sed -i "s|mongodb_password|$mongodb_password|g" files/mongo/deployment.yaml

microk8s.kubectl apply -f files/mongo/ -n $namespace
wait_for_pod $namespace mongodb
#mongo kurulduktan sonra bu pod a bağlanarak yeni bir db oluşturma işlemi yapılacak
microk8s.kubectl exec -it -n "${namespace}" "deployment/mongodb" -- mongo "sem" -u "${mongodb_username}" -p "${mongodb_password}" --authenticationDatabase admin --eval "db.createCollection('init')"

print_message "Mongo sunucusu kurulumu tamamlandı."
#-----------------Mongo Kurulumu----------------------------!>

#<!-----------------NLM Kurulumu----------------------------
print_message "NLM sunucusu sizin için kuruluyor..."
sed -i "s|NLM_PATH|$CURRENT_DIR/files/nlm|g" files/nlm/storage.yaml
sed -i "s|mongodb_username|$mongodb_username|g" files/nlm/conf/db.js
sed -i "s|mongodb_password|$mongodb_password|g" files/nlm/conf/db.js
sed -i "s|namespace|$namespace|g" files/nlm/conf/db.js
sed -i "s|elk_api_key|$elk_api_key|g" files/nlm/conf/db.js
sed -i "s|serverIP|$ip_address|g" files/nlm/conf/db.js

microk8s.kubectl apply -f files/nlm/ -n $namespace
wait_for_pod $namespace nlm
upsert_config Notification.SERVER "http://$ip_address:30040"

print_message "NLM sunucusu kurulumu tamamlandı."
#-----------------NLM Kurulumu----------------------------!>


print_message "SEM ERP hizmeti kurulmuştur \n
SEMERP için http://$ip_address:30080/sem adresini kullanabilirsiniz.\n
RabbitMQ için http://$ip_address:30962 adresini kullanabilirsiniz.\n
Kibana için http://$ip_address:30601 adresini kullanabilirsiniz.\n
NLM için http://$ip_address:30040 adresini kullanabilirsiniz. \n
MongoDB Express için http://$ip_address:30082 adresini kullanabilirsiniz.
kullanıcı adı: $mongodb_username \n
şifre: $mongodb_password \n
"
