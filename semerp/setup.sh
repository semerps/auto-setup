#!/bin/sh

#ZIP dosyasının indirme bağlantısı
apt update
apt install -y unzip
unzip files/setup.zip -d files
CURRENT_DIR=$(pwd)
namespace="semerp"
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
    sqlcmd -S "${mssql_addrs},${mssql_port}" -U "${mssql_user}" -P "${mssql_pass}" -d "${database}" -Q "${sql}"
  else
    sqlcmd -S "${mssql_addrs},${mssql_port}" -U "${mssql_user}" -P "${mssql_pass}" -Q "${sql}"
  fi
}

#Database oluşturma fonksiyonu
create_database() {
  local database="$1"
  local sql="CREATE DATABASE [${database}];"
  sql_exec "${sql}"
}

# Veritabanı geri yükleme işlemini gerçekleştiren fonksiyon
restore_database() {
  # Parametreleri ayarla
  local BACKUP_FILE="$1"
  local DATABASE="$2"

  # Veritabanının var olup olmadığını kontrol etme
  local SQL_CHECK_DB="IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = '${DATABASE}') CREATE DATABASE [${DATABASE}];"

  # Veritabanını kontrol et ve gerekiyorsa oluştur
  sql_exec "${SQL_CHECK_DB}"

  # Geri yükleme için SQL komutu
  local SQL_RESTORE="RESTORE DATABASE [${DATABASE}] FROM DISK='${BACKUP_FILE}' WITH REPLACE, STATS=5;"
  print_message "Restoring database: $DATABASE from backup file: $BACKUP_FILE"

  # SQLCMD ile geri yükleme işlemini başlatma
  sql_exec "${SQL_RESTORE}"
}



# Fonksiyonu çağırın
#wait_for_pod my-namespace my-deployment


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
    sudo microk8s enable istio

    # kubectl için alias'ı ekleyin
    echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
    source ~/.bashrc
    sudo usermod -a -G microk8s elduser
    sudo chown -R elduser ~/.kube
    newgrp microk8s

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


if command -v sqlcmd == "/opt/mssql-tools/bin/sqlcmd"; then
  print_message "SQLCMD kurulu."
else
  curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
  # Microsoft'un APT deposunu sisteminize ekleyin
  curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
  # Sistemi güncelle
  sudo apt-get update

  # MSSQL-Tools'u yükle
  sudo apt-get install mssql-tools unixodbc-dev

  # MSSQL-Tools araçlarını PATH'e ekle
  echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
  source ~/.bashrc

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

#<!------------------Redis Kurulumu----------------------------
print_message "Redis sunucusu sizin için kuruluyor..."
microk8s.kubectl apply -f files/redis/ -n $namespace
wait_for_pod $namespace redis
print_message "Redis sunucusu kurulumu tamamlandı."
#------------------Redis Kurulumu----------------------------!>

#<!-----------------SEM Kurulumu----------------------------
print_message "SEM sunucusu sizin için kuruluyor..."

sed -i "s|SEM_SETUP_DIR|$CURRENT_DIR/sem|g" files/semerp/volume.yaml
sed -i "s|MSSQL_ADDRS|$mssql_addrs|g" files/conf/server.xml
sed -i "s|MSSQL_PORT|$mssql_port|g" files/conf/server.xml
sed -i "s|MSSQL_USER|$mssql_user|g" files/conf/server.xml
sed -i "s|MSSQL_PASS|$mssql_pass|g" files/conf/server.xml
sed -i "s|MSSQL_SEM_DB|$mssql_sem_db|g" files/conf/server.xml
sed -i "s|MSSQL_GANTT_DB|$mssql_gantt_db|g" files/conf/server.xml
microk8s.kubectl apply -f files/semerp/ -n $namespace
wait_for_pod $namespace semerp-latest
print_message "SEM sunucusu kurulumu tamamlandı."
#-----------------SEM Kurulumu----------------------------!>
