#!/bin/bash

set -e

# Убедитесь, что скрипт запускается с правами суперпользователя
if [ "$EUID" -ne 0 ]; then
   echo "Этот скрипт должен быть запущен с правами суперпользователя" 
   exit 1
fi

# Путь к CSV файлам
csv_file="users.csv"
remove_csv_file="remove_users.csv"
log_file="user_management.log"

# Функция для создания пользователей
create_users() {
    # Запрос имени пользователя, пароля и роли
    read -p "Введите имя пользователя: " username
    read -sp "Введите пароль: " password
    echo
    read -p "Введите роль пользователя: " role

    # Запись в CSV файл
    echo "$username;$password;$role" >> "$csv_file"
    echo "Пользователь $username добавлен в $csv_file." | tee -a "$log_file"

    # Чтение CSV файла и создание пользователей
    while IFS=';' read -r csv_username csv_password csv_role; do
        echo "Обработка пользователя: $csv_username" | tee -a "$log_file"
        if id "$csv_username" &>/dev/null; then
            echo "Пользователь $csv_username уже существует, пропускаем..." | tee -a "$log_file"
            continue
        fi

        echo "Создание пользователя $csv_username..." | tee -a "$log_file"
        if useradd -m -d /home/"$csv_username" -s /bin/bash "$csv_username"; then
            echo "Пользователь $csv_username успешно создан." | tee -a "$log_file"
        else
            echo "Ошибка при создании пользователя $csv_username." | tee -a "$log_file"
            continue
        fi
        
        echo "Назначение пароля для $csv_username..." | tee -a "$log_file"
        echo "$csv_username:$csv_password" | chpasswd

        echo "Генерация SSH-ключей для $csv_username..." | tee -a "$log_file"
        su - "$csv_username" -c "mkdir -p ~/.ssh && ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ''"

        # Проверка и создание группы для роли
        if ! getent group "$csv_role" > /dev/null; then
            echo "Создание группы для роли $csv_role..." | tee -a "$log_file"
            groupadd "$csv_role"
        fi

        # Добавление пользователя в группу на основе роли
        usermod -aG "$csv_role" "$csv_username"

        # Проверка и создание директории для роли
        role_dir="/var/$csv_role"
        if [ ! -d "$role_dir" ]; then
            echo "Создание директории для роли $csv_role..." | tee -a "$log_file"
            mkdir -p "$role_dir"
            chown :"$csv_role" "$role_dir"
            chmod 770 "$role_dir"
        fi

        echo "Пользователь $csv_username создан и добавлен в группу $csv_role." | tee -a "$log_file"
    done < "$csv_file"
}

# Функция для удаления пользователей
remove_users() {
    if [ -f "$remove_csv_file" ]; then
        # Создание временного файла для обновленного списка пользователей
        temp_file=$(mktemp)

        while IFS=';' read -r csv_username csv_password csv_role; do
            if grep -q "^$csv_username$" "$remove_csv_file"; then
                echo "Удаление пользователя: $csv_username" | tee -a "$log_file"
                if id "$csv_username" &>/dev/null; then
                    if userdel -r "$csv_username"; then
                        echo "Пользователь $csv_username успешно удален." | tee -a "$log_file"
                    else
                        echo "Ошибка при удалении пользователя $csv_username." | tee -a "$log_file"
                        echo "$csv_username;$csv_password;$csv_role" >> "$temp_file"
                    fi
                else
                    echo "Пользователь $csv_username не найден, пропускаем..." | tee -a "$log_file"
                fi
            else
                # Если пользователь не подлежит удалению, сохраняем его в временный файл
                echo "$csv_username;$csv_password;$csv_role" >> "$temp_file"
            fi
        done < "$csv_file"

        # Перемещаем временный файл на место оригинального CSV файла
        mv "$temp_file" "$csv_file"
    else
        echo "Файл $remove_csv_file не найден, пропускаем удаление пользователей." | tee -a "$log_file"
    fi
}

# Главное меню
while true; do
    echo "Выберите действие:"
    echo "1. Создать пользователей"
    echo "2. Удалить пользователей"
    echo "3. Выйти"
    read -p "Введите номер действия: " choice

    case $choice in
        1)
            create_users
            ;;
        2)
            remove_users
            ;;
        3)
            echo "Выход из программы."
            exit 0
            ;;
        *)
            echo "Неверный выбор, попробуйте снова."
            ;;
    esac
done