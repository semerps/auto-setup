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