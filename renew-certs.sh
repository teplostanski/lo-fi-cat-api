#!/bin/bash

# Скрипт для обновления SSL сертификатов и перезагрузки Nginx

set -e

DOMAIN="api-lofi.teplostanski.me"

echo "🔄 Обновление SSL сертификатов для $DOMAIN..."

# Обновляем сертификаты через certbot
docker compose run --rm certbot renew

# Копируем обновленные сертификаты
if [ -f "./nginx/certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
  cp "./nginx/certbot/conf/live/$DOMAIN/fullchain.pem" "./nginx/ssl/cert.pem"
  cp "./nginx/certbot/conf/live/$DOMAIN/privkey.pem" "./nginx/ssl/key.pem"
  chmod 644 "./nginx/ssl/cert.pem"
  chmod 600 "./nginx/ssl/key.pem"
  echo "✅ Сертификаты обновлены и скопированы"
  
  # Перезагружаем Nginx
  echo "Перезагружаем Nginx..."
  docker compose exec nginx nginx -s reload 2>/dev/null || docker compose restart nginx
  echo "✅ Nginx перезагружен"
else
  echo "⚠️  Сертификаты не найдены, возможно они не требуют обновления"
fi
