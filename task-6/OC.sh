#!/bin/bash

# Скрипт для автоматизации настройки системы

# --- Глобальные переменные ---
os=""
package_manager=""
log_file="/tmp/setup.log"
error_file="/tmp/setup_error.log"

# --- Функции ---

log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

log_error() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - ОШИБКА: $1" >> "$error_file"
  log_message "ОШИБКА: $1"
}

# Определение ОС и менеджера пакетов
detect_os() {
  os=$(uname -s)
  log_message "Обнаружена ОС: $os"

  case "$os" in
    Linux)
      # Проверка наличия популярных менеджеров пакетов
      if command -v apt &> /dev/null; then
        package_manager="apt"
      elif command -v yum &> /dev/null; then
        package_manager="yum"
      elif command -v dnf &> /dev/null; then
        package_manager="dnf"
      elif command -v pacman &> /dev/null; then
        package_manager="pacman"
      else
        log_error "Не найден поддерживаемый менеджер пакетов."
        exit 1
      fi
      log_message "Менеджер пакетов: $package_manager"
      ;;
    Darwin)
      if command -v brew &> /dev/null; then
        package_manager="brew"
      else
        log_error "Homebrew не найден. Пожалуйста, установите его."
        exit 1
      fi
      log_message "Менеджер пакетов: $package_manager"
      ;;
    *)
      log_error "Неподдерживаемая ОС: $os"
      exit 1
      ;;
  esac
}

# Установка пакетов
install_packages() {
  local packages="$@"
  log_message "Установка пакетов: $packages"

  case "$package_manager" in
    apt)
      sudo apt update &>> "$log_file" || { log_error "Ошибка apt update"; exit 1; }
      sudo apt install -y $packages &>> "$log_file" || { log_error "Ошибка apt install для $packages"; exit 1; }
      ;;
    yum)
      sudo yum install -y $packages &>> "$log_file" || { log_error "Ошибка yum install для $packages"; exit 1; }
      ;;
    dnf)
      sudo dnf install -y $packages &>> "$log_file" || { log_error "Ошибка dnf install для $packages"; exit 1; }
      ;;
    pacman)
      sudo pacman -Syu --noconfirm $packages &>> "$log_file" || { log_error "Ошибка pacman install для $packages"; exit 1; }
      ;;
    brew)
      brew install $packages &>> "$log_file" || { log_error "Ошибка brew install для $packages"; exit 1; }
      ;;
    *)
      log_error "Неподдерживаемый менеджер пакетов: $package_manager"
      exit 1
      ;;
  esac

  log_message "Пакеты успешно установлены: $packages"
}

# Настройка сервисов (Пример: SSH)
configure_services() {
  log_message "Настройка сервисов..."

  # Пример: Отключение аутентификации по паролю для SSH (Лучшая практика безопасности)
  if [ -f /etc/ssh/sshd_config ]; then
    sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config &>> "$log_file" || log_error "Не удалось отключить аутентификацию по паролю SSH"
    sudo systemctl restart sshd &>> "$log_file" || log_error "Не удалось перезапустить сервис SSH"
    log_message "SSH настроен для отключения аутентификации по паролю."
  else
    log_message "sshd_config не найден, пропуск настройки SSH."
  fi

  log_message "Сервисы настроены."
}

# Создание тестовой базы данных (Пример: MySQL)
create_test_db() {
  log_message "Создание тестовой базы данных..."

  # Проверка, установлен ли MySQL
  if command -v mysql &> /dev/null; then
    # Установка переменной для пароля root
    local root_password="Marcus2!"  # Замените на текущий пароль

    # Создание базы данных и пользователя (замените на ваши настройки)
    sudo mysql -u root -p"$root_password" -e "CREATE DATABASE testdb;" &>> "$log_file" || log_error "Не удалось создать базу данных"
    
    log_message "Тестовая база данных создана."
  else
    log_message "MySQL не найден, пропуск создания базы данных."
  fi

  log_message "Создание тестовой базы данных завершено."
}

# Настройка файрвола (Пример: UFW - Uncomplicated Firewall)
configure_firewall() {
  log_message "Настройка файрвола..."

  # Проверка, установлен ли UFW
  if command -v ufw &> /dev/null; then
    # Разрешение SSH и включение файрвола
    sudo ufw allow ssh &>> "$log_file" || log_error "Не удалось разрешить SSH через UFW"
    sudo ufw --force enable &>> "$log_file" || log_error "Не удалось включить UFW"
    log_message "Файрвол настроен для разрешения SSH."
  else
    log_message "UFW не найден, пропуск настройки файрвола."
  fi

  log_message "Настройка файрвола завершена."
}

# --- Основной скрипт ---

# Инициализация
echo "Запуск автоматической настройки..."
detect_os

# Установка основных пакетов (Настройте этот список!)
install_packages "git mysql-server"

# Настройка сервисов
configure_services

# Создание тестовой базы данных
create_test_db

# Настройка файрвола
configure_firewall

echo "Автоматическая настройка завершена! Проверьте $log_file и $error_file для деталей."
exit 0