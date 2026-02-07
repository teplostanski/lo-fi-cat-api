#!/bin/bash

# Скрипт для проверки логов и диагностики проблем

echo "=== Логи Nginx ==="
docker compose logs --tail=50 nginx

echo ""
echo "=== Логи Backend ==="
docker compose logs --tail=50 lofi-cat-backend

echo ""
echo "=== Проверка конфигурации Nginx ==="
docker compose exec nginx nginx -t 2>&1 || echo "Контейнер не запущен, проверяем файлы..."

echo ""
echo "=== Статус контейнеров ==="
docker compose ps

echo ""
echo "=== Проверка доступности бэкенда ==="
docker compose exec lofi-cat-backend wget -q -O- http://localhost:8090/info 2>&1 || echo "Backend недоступен или wget отсутствует"
