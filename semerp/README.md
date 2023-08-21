# Auto-Setup Projesi
Bu proje, SEM ERP ve bağlı bileşenlerinin (MSSQL, RabbitMQ, Redis, ElasticSearch, Mongodb, NLM Server, Document Converter) otomatik kurulumunu sağlamak için hazırlanmıştır. Kurulum süreci, setup.sh betiği aracılığıyla gerçekleştirilir.

# Kurulum 
1. Terminali açın, projeyi çekin ve setup projenin ana dizinine gidin:
```bash
git clone https://github.com/semerps/auto-setup && cd auto-setup/semerp && chmod +x setup.sh && sudo ./setup.sh
```

2. `setup.sh` betiğini çalıştırarak kurulum sürecini başlatın:
3. Betik, sizden gerekli bilgileri girmenizi isteyecektir. Ekrandaki talimatları takip edin ve istenen bilgileri girin.
4. Kurulum tamamlandıktan sonra, SEM ERP ve bağlı bileşenlerinin başarıyla kurulduğunu doğrulamak için kubernetes dashboard'unu kontrol edin.

# Notlar

* Bu betik, kurulum sırasında gerekli olan MSSQL-Tools, Docker, Kubernete ve servislerini otomatik olarak yükler.
* Eğer mevcut bir MSSQL sunucusuna bağlanmak istiyorsanız, betik sırasında gerekli bilgileri girebilirsiniz. Aksi takdirde, betik yeni bir MSSQL sunucusu kuracaktır.  / İsteğe bağlı olarak `files/mssql/data/dbs` dizini içerisine yedek `.bak` dosyalarını koyarak, MSSQL sunucusunu yedekten geri yükleyebilirsiniz.
* Betik, bağlı bileşenlerin (RabbitMQ, Redis,ElasticSearch, Mongodb, NLM Server , Document Converter) kurulumunu da gerçekleştirir.

# Sorun Giderme
Eğer herhangi bir sorunla karşılaşırsanız, betiğin çıktısındaki hata mesajlarını inceleyin. Gerekirse, betiği düzenleyerek hatalı kısımları düzeltebilir ve yeniden çalıştırabilirsiniz.


# Veritabanı Yedekleme
Bu proje ayrıca, belirtilen SQL veritabanını düzenli olarak yedekleyen bir Kubernetes CronJob da içermektedir. Bu CronJob, her gün gece yarısı çalışacak ve veritabanını yedekleyecektir.

## Yedekleme İşlemi
Yedekleme işlemi, önceden belirtilen bir yedekleme dizinine yedeklerin kaydedilmesi ile gerçekleştirilir. Ayrıca, bu işlem 180 gün ve daha eski yedeklemeleri otomatik olarak silecek, böylece depolama alanı tükenmez. Yedekler sql sunucu içerisindeki `/var/opt/mssql/data/backup` klasörüne alınır. Genelde bu dosyada auto setup projesinin mssql projesinin içerisindeki `data\backup`dosyasıdır.
## Yapılandırma
CronJob'un doğru çalışması için, gerekli environment değişkenlerinin (`SA_PASSWORD`, `NAMESPACE`, `DB_NAME` vb.) değerleri ile doldurulması gerekmektedir. DB_NAME için dizi kullanabilirsiniz (sem,sem-gantt vb.)

## Sorun Giderme
Eğer yedekleme işlemiyle ilgili herhangi bir sorunla karşılaşırsanız, Kubernetes loglarını kontrol edin. Bunun yanı sıra, CronJob'un yapılandırmasının doğru olduğundan ve gerekli dizinlerin/erişim izinlerinin düzgün bir şekilde ayarlandığından emin olun.
