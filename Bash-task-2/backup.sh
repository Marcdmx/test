#!/bin/bash

set -e

# Параметры
source_dir="/path/to/source"  # Директория для резервного копирования
backup_dir="/path/to/backup"  # Директория для хранения резервных копий
log_file="/var/log/backup.log"
error_log="/var/log/backup_error.log"
timestamp=$(date +"%Y%m%d%H%M%S")

# Создание директории для резервных копий, если её нет
mkdir -p "$backup_dir"

# Создание директории для резервного копирования, если её нет
mkdir -p "$source_dir"

# Функция для записи в лог
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$log_file"
}

# Функция для записи ошибок
log_error() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$error_log"
}

# Инкрементальное резервное копирование с помощью rsync
rsync -av --delete "$source_dir/" "$backup_dir/incremental_$timestamp" 1>>"$log_file" 2>>"$error_log"

# Проверка успешности rsync
if [ $? -eq 0 ]; then
    log_message "Резервное копирование успешно завершено."
else
    log_error "Ошибка при резервном копировании."
    exit 1
fi

# Создание архива
tar -czf "$backup_dir/archive_$timestamp.tar.gz" -C "$backup_dir" "incremental_$timestamp" 1>>"$log_file" 2>>"$error_log"

# Проверка успешности tar
if [ $? -eq 0 ]; then
    log_message "Архив успешно создан."
else
    log_error "Ошибка при создании архива."
    exit 1
fi

# Проверка целостности архива
md5sum "$backup_dir/archive_$timestamp.tar.gz" > "$backup_dir/archive_$timestamp.md5" 2>>"$error_log"

# Проверка успешности md5sum
if [ $? -eq 0 ]; then
    log_message "Проверка целостности архива успешно завершена."
else
    log_error "Ошибка при проверке целостности архива."
    exit 1
fi