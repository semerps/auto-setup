#!/bin/bash

# Renk kodları
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SemERP Açılma Süresi Ölçüm Script'i (Interactive)     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Kullanıcıdan bilgi al
read -p "$(echo -e ${YELLOW}Namespace adı [semerp]: ${NC})" NAMESPACE
NAMESPACE=${NAMESPACE:-semerp}

read -p "$(echo -e ${YELLOW}Deployment YAML dosyası [deployment_fixed.yaml]: ${NC})" DEPLOYMENT_FILE
DEPLOYMENT_FILE=${DEPLOYMENT_FILE:-deployment_fixed.yaml}

read -p "$(echo -e ${YELLOW}Pod label selector [run=semerp-demo]: ${NC})" POD_LABEL
POD_LABEL=${POD_LABEL:-run=semerp-demo}

# Deployment dosyasından deployment adını çıkar
DEPLOYMENT_NAME=$(grep "name:" "$DEPLOYMENT_FILE" | grep -v "namespace\|container\|volume\|claim" | head -1 | awk '{print $2}')

# NodePort'u deployment dosyasından oku
NODE_PORT=$(grep "nodePort:" "$DEPLOYMENT_FILE" | head -1 | awk '{print $2}')
if [ -z "$NODE_PORT" ]; then
    read -p "$(echo -e ${YELLOW}NodePort numarası [30082]: ${NC})" NODE_PORT
    NODE_PORT=${NODE_PORT:-30082}
fi

# Sunucu IP'sini al
read -p "$(echo -e ${YELLOW}Sunucu IP adresi [192.168.34.49]: ${NC})" SERVER_IP
SERVER_IP=${SERVER_IP:-192.168.34.49}

# Service URL'i oluştur
SERVICE_URL="http://${SERVER_IP}:${NODE_PORT}/sem"
CHECK_INTERVAL=30  # Her 30 saniyede bir kontrol

# Log dosyaları
LOG_DIR="startup-logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
mkdir -p "$LOG_DIR"
ALL_LOGS="$LOG_DIR/all_logs_${TIMESTAMP}.txt"
ERROR_LOGS="$LOG_DIR/errors_${TIMESTAMP}.txt"
WARNING_LOGS="$LOG_DIR/warnings_${TIMESTAMP}.txt"
EXCEPTION_LOGS="$LOG_DIR/exceptions_${TIMESTAMP}.txt"
SUMMARY="$LOG_DIR/summary_${TIMESTAMP}.txt"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Konfigürasyon:${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT_NAME"
echo "Deployment File: $DEPLOYMENT_FILE"
echo "Pod Label: $POD_LABEL"
echo "Service URL: $SERVICE_URL"
echo "Kontrol Aralığı: ${CHECK_INTERVAL} saniye"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Onay al
read -p "$(echo -e ${YELLOW}Devam etmek istiyor musunuz? [E/h]: ${NC})" CONFIRM
CONFIRM=${CONFIRM:-E}
if [[ ! "$CONFIRM" =~ ^[Ee]$ ]]; then
    echo -e "${RED}İptal edildi.${NC}"
    exit 0
fi

echo ""

# Mevcut pod'u kontrol et
EXISTING_POD=$(microk8s kubectl get pod -n $NAMESPACE -l run=semerp-demo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$EXISTING_POD" ]; then
    # Pod yok, deployment'ı uygula
    echo -e "${YELLOW}Mevcut pod bulunamadı. Deployment uygulanıyor...${NC}"
    microk8s kubectl apply -f deployment_fixed.yaml -n $NAMESPACE
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Deployment başarısız!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Deployment başarılı!${NC}"
    echo ""
    
    # Yeni pod'un başlamasını bekle
    echo -e "${YELLOW}Yeni pod'un başlaması bekleniyor...${NC}"
    microk8s kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l run=semerp-demo -n $NAMESPACE --timeout=300s
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Pod başlamadı!${NC}"
        exit 1
    fi
    
    POD_NAME=$(microk8s kubectl get pod -n $NAMESPACE -l run=semerp-demo -o jsonpath='{.items[0].metadata.name}')
    echo -e "${GREEN}Pod başladı: $POD_NAME${NC}"
else
    # Pod var, restart et
    echo -e "${YELLOW}Mevcut pod bulundu: $EXISTING_POD${NC}"
    echo -e "${YELLOW}Pod restart ediliyor...${NC}"
    
    # Pod'u sil (Deployment otomatik olarak yeni pod oluşturur)
    microk8s kubectl delete pod $EXISTING_POD -n $NAMESPACE
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Pod silme başarısız!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Pod silindi, yeni pod oluşturuluyor...${NC}"
    echo ""
    
    # Yeni pod'un başlamasını bekle
    echo -e "${YELLOW}Yeni pod'un başlaması bekleniyor...${NC}"
    sleep 5
    microk8s kubectl wait --for=jsonpath='{.status.phase}'=Running pod -l run=semerp-demo -n $NAMESPACE --timeout=300s
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Yeni pod başlamadı!${NC}"
        exit 1
    fi
    
    POD_NAME=$(microk8s kubectl get pod -n $NAMESPACE -l run=semerp-demo -o jsonpath='{.items[0].metadata.name}')
    echo -e "${GREEN}Yeni pod başladı: $POD_NAME${NC}"
fi

echo ""

# Başlangıç zamanını kaydet
START_TIME=$(date +%s)
START_DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo -e "${YELLOW}Başlangıç zamanı: $START_DATE${NC}"
echo -e "${YELLOW}Uygulama açılması bekleniyor (curl ile kontrol ediliyor)...${NC}"
echo ""

# Curl ile kontrol et
ATTEMPT=0
while true; do
    ATTEMPT=$((ATTEMPT + 1))
    ELAPSED=$(($(date +%s) - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))
    
    printf "\r${YELLOW}Deneme #${ATTEMPT} - Geçen süre: ${MINUTES}dk ${SECONDS}sn${NC}"
    
    # Curl ile kontrol (timeout 60 saniye)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 60 "$SERVICE_URL" 2>/dev/null)
    
    # HTTP 200-399 kodlar = uygulama açıldı (404 hariç!)
    # 404 = endpoint henüz hazır değil, uygulama tam açılmamış
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo ""
        echo ""
        END_TIME=$(date +%s)
        END_DATE=$(date '+%Y-%m-%d %H:%M:%S')
        TOTAL_DURATION=$((END_TIME - START_TIME))
        TOTAL_MINUTES=$((TOTAL_DURATION / 60))
        TOTAL_SECONDS=$((TOTAL_DURATION % 60))
        
        echo -e "${GREEN}✅ BAŞARILI! Uygulama açıldı!${NC}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}Başlangıç:${NC} $START_DATE"
        echo -e "${GREEN}Bitiş:${NC}     $END_DATE"
        echo -e "${GREEN}Toplam Süre:${NC} ${TOTAL_MINUTES} dakika ${TOTAL_SECONDS} saniye"
        echo -e "${GREEN}HTTP Kodu:${NC} $HTTP_CODE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Önerilen probe ayarları
        SUGGESTED_INITIAL_DELAY=$((TOTAL_MINUTES * 60 / 3))  # Toplam sürenin 1/3'ü
        SUGGESTED_FAILURE=$((TOTAL_MINUTES + 10))             # Toplam süre + 10 dk buffer
        
        echo -e "${YELLOW}📊 ÖNERİLEN PROBE AYARLARI:${NC}"
        echo ""
        echo "startupProbe:"
        echo "  tcpSocket:"
        echo "    port: 8090"
        echo "  initialDelaySeconds: $SUGGESTED_INITIAL_DELAY"
        echo "  failureThreshold: $SUGGESTED_FAILURE"
        echo "  periodSeconds: 30"
        echo "  timeoutSeconds: 10"
        echo ""
        echo "readinessProbe:"
        echo "  httpGet:"
        echo "    path: /sem"
        echo "    port: 8090"
        echo "  initialDelaySeconds: 60"
        echo "  periodSeconds: 15"
        echo "  timeoutSeconds: 30"
        echo "  failureThreshold: 3"
        echo ""
        
        break
    fi
    
    # 60 dakikadan fazla bekleme
    if [ $ELAPSED -gt 3600 ]; then
        echo ""
        echo ""
        echo -e "${RED}❌ TIMEOUT! 60 dakika geçti, uygulama hala açılmadı.${NC}"
        echo ""
        echo "Son logları kontrol edin:"
        echo "  microk8s kubectl logs -n $NAMESPACE $POD_NAME --tail=100"
        exit 1
    fi
    
    sleep $CHECK_INTERVAL
done

# ============================================
# LOGLARI TOPLA VE ANALİZ ET
# ============================================
echo ""
echo -e "${YELLOW}📋 Startup logları toplanıyor...${NC}"

# Tüm logları kaydet
microk8s kubectl logs -n $NAMESPACE $POD_NAME > "$ALL_LOGS" 2>&1
echo -e "${GREEN}✓ Tüm loglar kaydedildi: $ALL_LOGS${NC}"

# ERROR loglarını filtrele
grep -i "error" "$ALL_LOGS" > "$ERROR_LOGS" 2>/dev/null
ERROR_COUNT=$(wc -l < "$ERROR_LOGS" | tr -d ' ')
echo -e "${GREEN}✓ $ERROR_COUNT adet ERROR bulundu: $ERROR_LOGS${NC}"

# WARNING loglarını filtrele
grep -i "warning\|warn" "$ALL_LOGS" > "$WARNING_LOGS" 2>/dev/null
WARNING_COUNT=$(wc -l < "$WARNING_LOGS" | tr -d ' ')
echo -e "${GREEN}✓ $WARNING_COUNT adet WARNING bulundu: $WARNING_LOGS${NC}"

# Exception loglarını filtrele
grep -i "exception\|stacktrace" "$ALL_LOGS" > "$EXCEPTION_LOGS" 2>/dev/null
EXCEPTION_COUNT=$(wc -l < "$EXCEPTION_LOGS" | tr -d ' ')
echo -e "${GREEN}✓ $EXCEPTION_COUNT adet Exception bulundu: $EXCEPTION_LOGS${NC}"

# Özet rapor oluştur
cat > "$SUMMARY" << SUMMARY_EOF
=================================================================
SemERP Startup Analizi
=================================================================
Tarih: $(date '+%Y-%m-%d %H:%M:%S')
Pod: $POD_NAME
Namespace: $NAMESPACE

-----------------------------------------------------------------
AÇILMA SÜRESİ
-----------------------------------------------------------------
Başlangıç: $START_DATE
Bitiş: $END_DATE
Toplam Süre: ${TOTAL_MINUTES} dakika ${TOTAL_SECONDS} saniye

-----------------------------------------------------------------
LOG İSTATİSTİKLERİ
-----------------------------------------------------------------
Toplam Log Satırı: $(wc -l < "$ALL_LOGS" | tr -d ' ')
ERROR Sayısı: $ERROR_COUNT
WARNING Sayısı: $WARNING_COUNT
Exception Sayısı: $EXCEPTION_COUNT

-----------------------------------------------------------------
KRİTİK HATALAR
-----------------------------------------------------------------
SUMMARY_EOF

# Kritik hataları kontrol et
if grep -qi "OutOfMemoryError" "$ALL_LOGS"; then
    echo "✗ OutOfMemoryError tespit edildi!" >> "$SUMMARY"
fi

if grep -qi "Could not connect\|Connection refused" "$ALL_LOGS"; then
    echo "✗ Bağlantı hatası tespit edildi!" >> "$SUMMARY"
    grep -i "Could not connect\|Connection refused" "$ALL_LOGS" | head -3 >> "$SUMMARY"
fi

if grep -qi "Failed to" "$ALL_LOGS"; then
    echo "✗ Başarısız işlemler:" >> "$SUMMARY"
    grep -i "Failed to" "$ALL_LOGS" | head -5 >> "$SUMMARY"
fi

echo "" >> "$SUMMARY"
echo "-----------------------------------------------------------------" >> "$SUMMARY"
echo "DOSYALAR" >> "$SUMMARY"
echo "-----------------------------------------------------------------" >> "$SUMMARY"
echo "Tüm Loglar: $ALL_LOGS" >> "$SUMMARY"
echo "Hatalar: $ERROR_LOGS" >> "$SUMMARY"
echo "Uyarılar: $WARNING_LOGS" >> "$SUMMARY"
echo "Exception'lar: $EXCEPTION_LOGS" >> "$SUMMARY"
echo "=================================================================" >> "$SUMMARY"

echo ""
echo -e "${YELLOW}📊 Özet rapor oluşturuldu: $SUMMARY${NC}"
echo ""

# Pod durumunu göster
echo -e "${YELLOW}Pod Durumu:${NC}"
microk8s kubectl get pod -n $NAMESPACE -l run=semerp-demo
echo ""

echo -e "${GREEN}✅ Ölçüm tamamlandı!${NC}"
echo ""
echo -e "${YELLOW}📁 Tüm loglar şu dizine kaydedildi: $LOG_DIR${NC}"
echo ""
echo "Dosyalar:"
echo "  - Tüm loglar: $ALL_LOGS"
echo "  - Hatalar: $ERROR_LOGS ($ERROR_COUNT adet)"
echo "  - Uyarılar: $WARNING_LOGS ($WARNING_COUNT adet)"
echo "  - Exception'lar: $EXCEPTION_LOGS ($EXCEPTION_COUNT adet)"
echo "  - Özet rapor: $SUMMARY"
echo ""
echo -e "${GREEN}Özet raporu görüntülemek için: cat $SUMMARY${NC}"

