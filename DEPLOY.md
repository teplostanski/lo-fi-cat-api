# Инструкция по развертыванию на VPS

## 📋 Шаги развертывания

### 1. Подготовка VPS

```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем Docker и Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Устанавливаем Docker Compose (если еще нет)
sudo apt install docker-compose-plugin -y

# Перелогиниваемся для применения изменений группы
exit
# (затем снова подключитесь к VPS)
```

### 2. Подготовка проекта на VPS

**Вариант 1: Клонируем репозиторий (если есть git)**
```bash
git clone <your-repo-url> lo-fi-cat-api
cd lo-fi-cat-api
```

**Вариант 2: Загружаем через scp с локальной машины**
```bash
# На локальной машине (из директории проекта):
scp -r . user@vps-ip:~/lo-fi-cat-api

# На VPS:
cd ~/lo-fi-cat-api
```

**Вариант 3: Создаем файлы напрямую на VPS**
Если файлы уже есть на VPS, просто перейдите в директорию проекта:
```bash
cd ~/lo-fi-cat-api  # или путь где у вас проект
```

### 3. Настройка конфигурации

#### 3.1. Конфигурация Nginx:
- Домен уже указан: `api-lofi.teplostanski.me`
- Настройте DNS запись: A-запись `api-lofi` → IP вашего VPS
- SSL сертификат будет получен автоматически при первом деплое (или вручную через `./init-letsencrypt.sh`)

### 4. Развертывание

```bash
# Делаем скрипт исполняемым
chmod +x deploy.sh

# Запускаем развертывание
./deploy.sh
```

### 5. Проверка

```bash
# Проверяем статус контейнеров
docker-compose ps

# Смотрим логи
docker-compose logs -f

# Проверяем доступность
curl http://localhost/info
```

## 🔧 Полезные команды

```bash
# Просмотр логов
docker-compose logs -f lofi-cat-backend
docker-compose logs -f nginx

# Перезапуск сервисов
docker-compose restart

# Остановка
docker-compose down

# Обновление (после изменений в коде)
docker-compose build --no-cache
docker-compose up -d

# Просмотр использования ресурсов
docker stats
```

## 🔒 Настройка SSL (Let's Encrypt)

### Автоматическое получение SSL

SSL сертификат **автоматически получается** при первом развертывании через `./deploy.sh`.

Если нужно получить сертификат вручную:

```bash
# На VPS выполните:
chmod +x init-letsencrypt.sh
./init-letsencrypt.sh
```

Скрипт автоматически:
1. Остановит Nginx контейнер
2. Получит SSL сертификат через certbot в Docker
3. Скопирует сертификаты в нужный формат
4. Включит HTTPS конфигурацию в Nginx
5. Включит редирект с HTTP на HTTPS
6. Запустит Nginx обратно

### Автоматическое обновление сертификатов

Certbot контейнер **автоматически обновляет** сертификаты каждые 12 часов.

Для ручного обновления:
```bash
./renew-certs.sh
```

Или добавьте в crontab для дополнительной надежности:
```bash
crontab -e
# Добавьте (проверка раз в день):
0 2 * * * cd ~/lo-fi-cat-api && ./renew-certs.sh
```

## 📝 Структура проекта

```
lo-fi-cat-api/
├── docker-compose.yml      # Оркестрация контейнеров
├── Dockerfile              # Образ Go бэкенда
├── deploy.sh               # Скрипт развертывания
├── init-letsencrypt.sh     # Автоматическое получение SSL сертификата
├── renew-certs.sh          # Ручное обновление SSL сертификатов
├── nginx/
│   ├── nginx.conf          # Основная конфигурация Nginx
│   ├── conf.d/
│   │   └── lofi-cat.conf   # Конфигурация для Lofi Cat
│   └── ssl/                # SSL сертификаты (создается автоматически)
└── songs/                  # Музыкальные файлы
```

## ⚠️ Важные моменты

1. **Порты**: 
   - Nginx слушает на 80 и 443
   - Go сервер внутри Docker на 8090 (не доступен извне)

2. **Музыка**: 
   - Монтируется из `./songs` в контейнер
   - Можно использовать внешний том: `- /path/to/music:/music:ro`

3. **Фронтенд**: 
   - Отдельная сущность, не входит в Docker
   - Обращается к API через домен `api-lofi.teplostanski.me`

4. **Безопасность**:
   - Используйте firewall (ufw)
   - Настройте SSL для HTTPS
   - Ограничьте доступ к портам

## 🐛 Решение проблем

### Контейнеры не запускаются
```bash
docker-compose logs
# Проверьте логи на ошибки
```

### Nginx не проксирует запросы
```bash
# Проверьте конфигурацию
docker-compose exec nginx nginx -t

# Перезагрузите Nginx
docker-compose exec nginx nginx -s reload
```

### SSL сертификат не работает
- Убедитесь, что DNS запись настроена и указывает на VPS
- Проверьте, что порт 80 открыт для Let's Encrypt
- Проверьте права на файлы сертификатов: `ls -la nginx/ssl/`
- Проверьте логи Nginx: `docker compose logs nginx`
