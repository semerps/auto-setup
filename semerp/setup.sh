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

# SQL Server için SQL komutlarını çalıştıran fonksiyon
sql_exec() {
  local sql="$1"
  local database="$2"
  if [ "$database" ]; then
    /opt/mssql-tools/bin/sqlcmd -S "${mssql_addrs},${mssql_port}" -U "${mssql_user}" -P "${mssql_pass}" -d "${database}" -Q "${sql}"
  else
    /opt/mssql-tools/bin/sqlcmd -S "${mssql_addrs},${mssql_port}" -U "${mssql_user}" -P "${mssql_pass}" -Q "${sql}"
  fi
}

#Sem Konfigürasyon ayarlarını yapar
upsert_config() {
  local config_key="$1"
  local config_value="$2"

  # Anahtarın tanımlı olup olmadığına bakar
  local check_query="IF EXISTS (SELECT 1 FROM dbo.sys_config WHERE config_key = '${config_key}') SELECT 1 as 'exists' ELSE SELECT 0 as 'exists';"
  local exists=$(sql_exec "${check_query}" "${mssql_sem_db}" | tail -n 1 | tr -d '[:space:]')

  if [ "$exists" -eq "1" ]; then
    # Eğer anahtar varsa anahtar ı günceller
    local update_query="UPDATE dbo.sys_config SET config_value = '${config_value}' WHERE config_key = '${config_key}';"
    sql_exec "${update_query}" "${mssql_sem_db}"
    echo "Config key '${config_key}' updated with value '${config_value}'."
  else
    # Eğer anahtar yoksa anahtarı ekler
    local insert_query="INSERT INTO dbo.sys_config (config_key, config_value, version, created_by_id, date_created) VALUES ('${config_key}', '${config_value}', 0, 1, GETDATE());"
    sql_exec "${insert_query}" "${mssql_sem_db}"
    echo "Config key '${config_key}' added with value '${config_value}'."
  fi
}

#Database oluşturma fonksiyonu
create_database() {
  local database="$1"
  local collation="Turkish_CI_AS"  # Specify the desired collation, e.g., Turkish (case-insensitive, accent-sensitive)

  local sql="CREATE DATABASE [${database}] COLLATE ${collation};"
  sql_exec "${sql}"
}

# Veritabanı geri yükleme işlemini gerçekleştiren fonksiyon
restore_database() {
  # Parametreleri ayarla
  local BACKUP_FILE="$1"
  local DATABASE="$2"
  local collation="Turkish_CI_AS"  # Specify the desired collation, e.g., Turkish (case-insensitive, accent-sensitive)


  # Veritabanının var olup olmadığını kontrol etme
  local SQL_CHECK_DB="IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '${DATABASE}') CREATE DATABASE [${DATABASE}] COLLATE ${collation};"

  # Veritabanını kontrol et ve gerekiyorsa oluştur
  sql_exec "${SQL_CHECK_DB}"

  # Geri yükleme için SQL komutu
  local SQL_RESTORE="RESTORE DATABASE [${DATABASE}] FROM DISK='${BACKUP_FILE}' WITH REPLACE, STATS=5;"
  print_message "Restoring database: $DATABASE from backup file: $BACKUP_FILE"

  # SQLCMD ile geri yükleme işlemini başlatma
  sql_exec "${SQL_RESTORE}"
}

#------------------Fonksiyon Listesi----------------------------!>

#<!------------------Başlangıç----------------------------

echo "_______________________________________"
echo "
 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@# @
      @@@@%    @@              @@     @@@@#    @@@@@@@@@      @@@@@@         @
      @@@@%    @@            @@@*      @@&      @@@@@@@        @@@@@           @@
      @@@@%    @@@@@@@      @@@@        @       @@@@@@         &@@@@     @(     @
      @@@@%    @@@@@      @@@@@&                 @@@@,          @@@@           @@
      %@@@     @@@@      @@@@@@     @            @@@@            @@@         @@@@
 @             @@,            @     @@    @@@     @*              @@     @     @@
 @@@         @@@                   @@@@   @@@     &     @@@@@@     @     @@
 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#@@@@@@@@@*@@@@@@@@@@@@@@@@@

 \n\n"

echo "
 __ __       __ _  _                             __
(_ |_ |V|---|_ |_)|_)   |/     __    |    __    (_  o |_  o  __|_  _  _  o
__)|__| |   |__| \|     |\ |_| | |_| | |_||||   __) | | | |  | |_)(_| /_ |
"

print_message "SEM ERP yi nasıl yüklemek istersiniz? \n
1) Sadece SEM-ERP ( Bu kurulumda sadece erp kurulur bağlı bulunan hiç bir mikroservis hizmeti kurulmaz.)\n
2) Tüm hizmetler ve bağlı mikro servisler ERP ve Gantt ile entegre edilerek kurulur."
read -p "Seçiminiz :" choice

case $choice in
  1)
    print_message "Sadece SEM ERP kurulacak."
    ;;
  2)
    print_message "Tüm hizmetler ve bağlı mikro servisler kurulacak"
    ;;
  *)
    print_message "Geçersiz seçenek: $choice"
    exit 1
    ;;
esac


# Özel korunan docker imajları için docker kullanıcı adı ve şifresi alınıyor

read -p "Lütfen Docker email adresiniz :" docker_email
read -p "Lütfen Docker kullancı adınız :" docker_user
read -p "Lütfen Docker pass :" docker_pass

print_message "Sunucunuzdaki kubernete ve docker hizmetleri kontrol ediliyor..."

if command -v microk8s kubectl == "/snap/bin/microk8s"; then
    print_message "Kubernetes kurulu."
    microk8s.kubectl create namespace $namespace
    microk8s.kubectl delete secret regcred -n $namespace
    microk8s.kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=${docker_user} --docker-password=${docker_pass} --docker-email=${docker_email} -n $namespace
else
    print_message "Sisteminizde kubernete kurulu olmadığı tespit edildi ve kurulum otomatik olarak başlatılıyor..."
    #!/bin/bash

    # microk8s'ı yükleyin ve etkinleştirin
    sudo snap install microk8s --classic
    sudo microk8s status --wait-ready
    sudo microk8s enable dashboard
    sudo microk8s enable dns
    sudo microk8s enable registry
    sudo microk8s enable community
    #sudo microk8s enable istio

    # kubectl için alias'ı ekleyin
    #echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc && source ~/.bashrc
    #newgrp microk8s
    #usermod -a -G microk8s $USER
    #chown -R $USER ~/.kube

    microk8s.kubectl create namespace $namespace

fi

if command -v docker == "/usr/bin/docker"; then
    print_message "Docker kurulu."
else
    print_message "Sisteminizde docker kurulu olmadığı tespit edildi ve kurulum otomatik olarak başlatılıyor..."

    # Docker'ı yükleyin ve etkinleştirin
    sudo apt-get update
    sudo apt-get install -y docker.io

fi


if command -v /opt/mssql-tools/bin/sqlcmd == "/opt/mssql-tools/bin/sqlcmd"; then
  print_message "SQLCMD kurulu."
else
  curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
  # Microsoft'un APT deposunu sisteminize ekleyin
  curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
  # Sistemi güncelle
  sudo apt-get update

  # MSSQL-Tools'u yükle
  sudo apt-get install mssql-tools unixodbc-dev

  # MSSQL-Tools yükleme işlemi tamamlandı
  print_message "MSSQL-Tools yükleme işlemi tamamlandı."
fi



#-------------------Başlangıç---------------------------!>

#<!------------------MSSQL Kurulumu----------------------------


read -p "MSSQL sunucusuna sahip misiniz? (Y/N): " user_has_mssql

if [ "$user_has_mssql" = "Y" ]; then
    read -p "Lütfen Veritabanı sunucunuzun adresini girin: " mssql_addrs
    read -p "Lütfen Veritabanı sunucunuzun port numarasını girin: " mssql_port
    read -p "Lütfen Veritabanı sunucunuzun kullanıcı adını girin: " mssql_user
    read -p "Lütfen Veritabanı sunucunuzun parolasını girin: " mssql_pass
    read -p "Sem-ERP için ayarladığınız DB adını girin: " mssql_sem_db
    read -p "Sem-Gantt için ayarladığınız DB adını girin: " mssql_gantt_db

    echo "Veritabanı sunucunuzun adresi: $mssql_addrs"

    # MSSQL sunucusuna bağlan
    if sql_exec "SELECT @@VERSION" > /dev/null; then
        print_message "MSSQL sunucusuna başarılı bir şekilde bağlandınız!"
    else
        print_message "Bağlantı hatası: MSSQL sunucusuna bağlanılamadı."
        exit 1
    fi
else
    #/var/opt/mssql/dbs yedekler klasörü
    read -p "Lütfen MSSQL sunucusu için bir parola girin: " mssql_pass
    mssql_addrs="localhost"
    mssql_port="31433"
    mssql_user="sa"
    mssql_sem_db="sem"
    mssql_gantt_db="sem_gantt"

    print_message "MSSQL sunucusu sizin için kuruluyor..."
    sed -i "s|MSSQL_PASSWORD|$mssql_pass|g" files/mssql/backupJob.yaml
    sed -i "s|NAME_SPACE|$namespace|g" files/mssql/backupJob.yaml
    sed -i "s|DB_NAMES_TO_BACKUP|$mssql_sem_db,$mssql_gantt_db|g" files/mssql/backupJob.yaml
    sed -i "s|MSSQL_PASSWORD|$mssql_pass|g" files/mssql/deployment.yaml
    sed -i "s|MSSQL_DATA_PATH|$CURRENT_DIR/files/mssql/data|g" files/mssql/storage.yaml
    microk8s.kubectl apply -f files/mssql/ -n $namespace
    wait_for_pod $namespace mssql

    read -p "DBS Klasöründeki yedekeeri MSSQL sunucusuna yüklemek istiyor musunuz? (Y/N): " restore_db

    if [ "$restore_db" = "Y" ]; then
        print_message "MSSQL sunucusuna yedekler klasöründeki yedekler yükleniyor..."
        restore_database "/var/opt/mssql/dbs/sem.bak" $mssql_sem_db
        restore_database "/var/opt/mssql/dbs/gantt.bak" $mssql_gantt_db
    else
        print_message "MSSQL sunucusuna databaseler oluşturuluyor..."
        create_database $mssql_sem_db
        create_database $mssql_gantt_db
    fi

    mssql_addrs="mssql.$namespace.svc.cluster.local"
    mssql_port="1433"

    print_message "MSSQL sunucusu kurulumu tamamlandı."
fi




#------------------MSSQL Kurulumu----------------------------!>

#<!------------------RabbitMQ Kurulumu----------------------------
print_message "RabbitMQ sunucusu sizin için kuruluyor..."
microk8s.kubectl apply -f files/rabbit/ -n $namespace
wait_for_pod $namespace rabbitmq
print_message "RabbitMQ sunucusu kurulumu tamamlandı."
#------------------RabbitMQ Kurulumu----------------------------!>

#<!------------------EKAP Banned Service Kurulumu----------------------------
#print_message "EKAP Banned Servisi sizin için kuruluyor..."
#microk8s.kubectl apply -f files/ekap/ -n $namespace
#wait_for_pod $namespace ekap
#print_message "EKAP Banned Servisi kurulumu tamamlandı."
#------------------RabbitMQ Kurulumu----------------------------!>

#<!------------------Redis Kurulumu----------------------------
print_message "Redis sunucusu sizin için kuruluyor..."
microk8s.kubectl apply -f files/redis/ -n $namespace
wait_for_pod $namespace redis
print_message "Redis sunucusu kurulumu tamamlandı."
#------------------Redis Kurulumu----------------------------!>


#<!-----------------SEM Kurulumu----------------------------
print_message "SEM sunucusu sizin için kuruluyor..."

sed -i "s|SEM_SETUP_DIR|$CURRENT_DIR/files|g" files/semerp/volume.yaml
sed -i "s|MSSQL_ADDRS|$mssql_addrs|g" files/conf/server.xml
sed -i "s|MSSQL_PORT|$mssql_port|g" files/conf/server.xml
sed -i "s|MSSQL_USER|$mssql_user|g" files/conf/server.xml
sed -i "s|MSSQL_PASS|$mssql_pass|g" files/conf/server.xml
sed -i "s|MSSQL_SEM_DB|$mssql_sem_db|g" files/conf/server.xml
sed -i "s|MSSQL_GANTT_DB|$mssql_gantt_db|g" files/conf/server.xml
microk8s.kubectl apply -f files/semerp/ -n $namespace
wait_for_pod $namespace semerp-latest
upsert_config BryntumServiceUri "http://$ip_address:30080/gantt-service"
upsert_config Notification.SERVER "false"
print_message "SEM sunucusu kurulumu tamamlandı."
#-----------------SEM Kurulumu----------------------------!>


#<!----------------Document Converter Kurulumu----------------------------
print_message "Document Converter sunucusu sizin için kuruluyor..."
microk8s.kubectl apply -f files/document-converter/ -n $namespace
wait_for_pod $namespace document-converter
upsert_config document-converter.address "http://$ip_address:30081"
print_message "Document Converter sunucusu kurulumu tamamlandı."
#----------------Document Converter Kurulumu----------------------------!>

#<!-----------------Parametre Kurulumu----------------------------
print_message "SEM ERP için gerekli parametrelerin yapılandırılması..."
read -p "Lütfen SEM ERP için firma adını giriniz: " ref_params
upsert_config company.title "$ref_params"
#-----------------Parametre Kurulumu----------------------------!>

if [ "$choice" = "1" ]; then
print_message "SEM ERP hizmeti kurulmuştur \n Erişim için http://$ip_address:30080/sem adresini kullanabilirsiniz. "
exit 1
fi


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
