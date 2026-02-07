#!/bin/bash

# Скрипт для развертывания Lofi Cat Backend API

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Проверка наличия Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker не установлен. Установите Docker и повторите попытку."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker не запущен или нет прав доступа. Убедитесь, что Docker запущен и вы в группе docker."
        exit 1
    fi
    
    success "Docker проверен"
}

# Проверка наличия docker-compose
check_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose не установлен."
        exit 1
    fi
    success "Docker Compose проверен"
}

# Проверка необходимых файлов
check_files() {
    local missing_files=()
    
    [ ! -f "docker-compose.yml" ] && missing_files+=("docker-compose.yml")
    [ ! -f "Dockerfile" ] && missing_files+=("Dockerfile")
    [ ! -d "nginx/conf.d" ] && missing_files+=("nginx/conf.d")
    [ ! -f "nginx/nginx.conf" ] && missing_files+=("nginx/nginx.conf")
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        error "Отсутствуют необходимые файлы:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        exit 1
    fi
    
    # Создаем необходимые директории для SSL
    mkdir -p ./nginx/ssl
    mkdir -p ./nginx/certbot/conf
    mkdir -p ./nginx/certbot/www
    
    success "Все необходимые файлы на месте"
}

# Функция развертывания
deploy() {
    info "Начинаем развертывание Lofi Cat Backend API..."
    
    # Останавливаем старые контейнеры
    info "Останавливаем старые контейнеры (если есть)..."
    docker compose down 2>/dev/null || true
    
    # Собираем образы
    info "Собираем Docker образы..."
    docker compose build --no-cache
    
    # Запускаем контейнеры
    info "Запускаем контейнеры..."
    docker compose up -d
    
    # Ждем немного для запуска
    sleep 3
    
    # Проверяем статус
    info "Проверяем статус контейнеров..."
    docker compose ps
    
    # Проверяем здоровье
    info "Ожидание готовности сервисов..."
    sleep 5
    
    # Автоматическое получение SSL сертификата (если еще нет)
    if [ ! -f "./nginx/ssl/cert.pem" ]; then
        warning "SSL сертификат не найден"
        read -p "Получить SSL сертификат автоматически? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if [ -f "./init-letsencrypt.sh" ]; then
                info "Запускаем автоматическое получение SSL..."
                chmod +x ./init-letsencrypt.sh
                ./init-letsencrypt.sh
            else
                warning "Скрипт init-letsencrypt.sh не найден, пропускаем SSL"
            fi
        fi
    fi
    
    if docker compose ps | grep -q "Up"; then
        success "Развертывание завершено успешно!"
        echo ""
        info "API доступен на:"
        if [ -f "./nginx/ssl/cert.pem" ]; then
            echo "  - HTTPS: https://api-lofi.teplostanski.me ✅"
            echo "  - HTTP:  http://api-lofi.teplostanski.me (редирект на HTTPS)"
        else
            echo "  - HTTP:  http://api-lofi.teplostanski.me"
            echo "  - HTTPS: https://api-lofi.teplostanski.me (настройте SSL через ./init-letsencrypt.sh)"
        fi
        echo ""
        info "Эндпоинты API:"
        echo "  - GET  /info          - информация о сервере"
        echo "  - GET  /fm            - аудио поток"
        echo "  - GET  /fm/info       - информация о музыке"
        echo "  - GET  /fm/info/cover - обложка трека"
        echo "  - WS   /ws            - WebSocket для обновлений"
    else
        error "Не все контейнеры запущены. Проверьте логи:"
        echo "  docker compose logs"
        exit 1
    fi
}

# Функция перезапуска
restart() {
    info "Перезапускаем сервисы..."
    docker compose restart
    success "Сервисы перезапущены"
    docker compose ps
}

# Функция остановки
stop() {
    info "Останавливаем сервисы..."
    docker compose down
    success "Сервисы остановлены"
}

# Функция просмотра логов
logs() {
    if [ -z "$1" ]; then
        docker compose logs -f
    else
        docker compose logs -f "$1"
    fi
}

# Функция статуса
status() {
    info "Статус контейнеров:"
    docker compose ps
    echo ""
    info "Использование ресурсов:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(docker compose ps -q) 2>/dev/null || echo "Контейнеры не запущены"
}

# Функция очистки
clean() {
    warning "Это удалит все контейнеры, сети и образы проекта."
    read -p "Продолжить? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Останавливаем и удаляем контейнеры..."
        docker compose down -v
        info "Удаляем образы..."
        docker compose down --rmi all 2>/dev/null || true
        success "Очистка завершена"
    else
        info "Очистка отменена"
    fi
}

# Главное меню
show_help() {
    echo "Использование: $0 [команда]"
    echo ""
    echo "Команды:"
    echo "  deploy   - Развернуть/обновить сервисы (по умолчанию)"
    echo "  restart  - Перезапустить сервисы"
    echo "  stop     - Остановить сервисы"
    echo "  logs     - Показать логи (можно указать сервис: logs nginx)"
    echo "  status   - Показать статус контейнеров"
    echo "  clean    - Удалить все контейнеры и образы"
    echo "  help     - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0              # Развернуть"
    echo "  $0 deploy       # Развернуть"
    echo "  $0 logs nginx   # Логи Nginx"
    echo "  $0 status       # Статус"
}

# Основная логика
main() {
    # Проверки
    check_docker
    check_compose
    check_files
    
    # Обработка команд
    case "${1:-deploy}" in
        deploy)
            deploy
            ;;
        restart)
            restart
            ;;
        stop)
            stop
            ;;
        logs)
            logs "$2"
            ;;
        status)
            status
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Неизвестная команда: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
