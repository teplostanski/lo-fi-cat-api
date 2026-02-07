#!/bin/bash

# Автоматическое получение SSL сертификата через Let's Encrypt

set -e

DOMAIN="api-lofi.teplostanski.me"
EMAIL="teplostanski@yandex.ru"

echo "🔒 Получение SSL сертификата для $DOMAIN..."

# Создаем необходимые директории
mkdir -p ./nginx/certbot/conf
mkdir -p ./nginx/certbot/www
mkdir -p ./nginx/ssl

# Проверяем, есть ли уже сертификат
if [ -d "./nginx/certbot/conf/live/$DOMAIN" ]; then
  echo "✅ Сертификат для $DOMAIN уже существует!"
  echo "Проверяем срок действия..."
  docker compose run --rm certbot certificates 2>/dev/null || true
  echo ""
  read -p "Получить новый сертификат? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

# Убеждаемся что nginx запущен (нужен для webroot валидации)
echo "Проверяем что Nginx запущен..."
docker compose up -d nginx
sleep 2

# Получаем сертификат через webroot (использует работающий nginx)
echo "Получаем сертификат через certbot (webroot mode)..."
docker compose run --rm --entrypoint "\
  certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN" certbot

# Функция для копирования сертификатов
copy_certificates() {
  if [ -f "./nginx/certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    cp "./nginx/certbot/conf/live/$DOMAIN/fullchain.pem" "./nginx/ssl/cert.pem"
    cp "./nginx/certbot/conf/live/$DOMAIN/privkey.pem" "./nginx/ssl/key.pem"
    chmod 644 "./nginx/ssl/cert.pem"
    chmod 600 "./nginx/ssl/key.pem"
    echo "✅ Сертификаты скопированы"
    return 0
  else
    echo "❌ Ошибка: сертификаты не найдены"
    return 1
  fi
}

# Копируем сертификаты в нужный формат для Nginx
echo "Копируем сертификаты..."
copy_certificates || exit 1

# Включаем HTTPS конфигурацию
echo "Включаем HTTPS в конфигурации Nginx..."
if [ -f "./nginx/conf.d/lofi-cat-https.conf.template" ]; then
  # Проверяем, не добавлена ли уже HTTPS секция
  if ! grep -q "listen 443 ssl" ./nginx/conf.d/lofi-cat.conf; then
    # Добавляем HTTPS секцию в конец файла
    cat ./nginx/conf.d/lofi-cat-https.conf.template >> ./nginx/conf.d/lofi-cat.conf
    echo "✅ HTTPS конфигурация добавлена"
  else
    echo "✅ HTTPS конфигурация уже присутствует"
  fi
  # Включаем редирект с HTTP на HTTPS
  sed -i 's/# return 301 https/return 301 https/g' ./nginx/conf.d/lofi-cat.conf
else
  echo "⚠️  Шаблон HTTPS конфигурации не найден, добавьте вручную"
fi

# Запускаем Nginx обратно
echo "Запускаем Nginx..."
docker compose up -d nginx

# Ждем запуска Nginx
sleep 3

# Проверяем конфигурацию
echo "Проверяем конфигурацию Nginx..."
sleep 2
if docker compose exec nginx nginx -t 2>/dev/null; then
  echo "✅ Конфигурация Nginx корректна"
  docker compose exec nginx nginx -s reload 2>/dev/null || docker compose restart nginx
else
  echo "❌ Ошибка в конфигурации Nginx, проверьте логи"
  docker compose logs nginx --tail=20
  exit 1
fi

echo ""
echo "✅ SSL сертификат получен и настроен!"
echo "🌐 API теперь доступен по HTTPS: https://$DOMAIN"
echo ""
echo "📝 Certbot будет автоматически обновлять сертификаты каждые 12 часов"
