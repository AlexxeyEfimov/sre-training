#!/bin/bash

# Проверка наличия аргумента
if [ -z "$1" ]; then
  echo "Использование: $0 <IP-адрес>"
  exit 1
fi

IPADDR="$1"
NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE="$NETPLAN_DIR/$(ls $NETPLAN_DIR | grep .yaml | head -n1)"

if [ ! -f "$NETPLAN_FILE" ]; then
  echo "Не найден YAML-файл в $NETPLAN_DIR"
  exit 1
fi

echo "Используется файл: $NETPLAN_FILE"

# Резервная копия
sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
echo "Создана резервная копия: ${NETPLAN_FILE}.bak"

# Временный файл для новой конфигурации
TMPFILE=$(mktemp)

# Копируем содержимое оригинального файла, удаляя старый блок enp0s8 (если есть)
grep -A 20 -B 20 '^\s*enp0s8:' "$NETPLAN_FILE" > /dev/null && \
  grep -v -A 10 '^\s*enp0s8:' "$NETPLAN_FILE" | grep -v '^\s*enp0s8:' > "$TMPFILE" || \
  cp "$NETPLAN_FILE" "$TMPFILE"

# Добавляем или обновляем enp0s8
cat <<EOF >> "$TMPFILE"

  enp0s8:
    dhcp4: no
    addresses: [$IPADDR/24]
EOF

# Проверяем корректность форматирования
if ! sudo netplan try --config="$TMPFILE"; then
  echo "Ошибка в формате Netplan. Отмена изменений."
  rm -f "$TMPFILE"
  exit 1
fi

# Перемещаем временный файл обратно
sudo mv "$TMPFILE" "$NETPLAN_FILE"

echo "Обновлена конфигурация интерфейса enp0s8 с IP: $IPADDR"

# Применение новой конфигурации
echo "Применяю новую сетевую конфигурацию..."
sudo netplan apply

# Обновление пакетов и установка SSH
echo "Обновляю список пакетов и устанавливаю openssh-server..."
sudo apt update && sudo apt install -y openssh-server

# Настройка SSH
echo "Запускаю и включаю автозапуск SSH..."
sudo systemctl start ssh
sudo systemctl enable ssh

# Разрешаем SSH в брандмауэре
echo "Разрешаю SSH через UFW..."
sudo ufw allow ssh

echo "✅ Настройка завершена!"
echo "- Интерфейс enp0s8 настроен с IP $IPADDR"
echo "- Интерфейс enp0s3 остался с DHCP"
echo "- SSH установлен, запущен и добавлен в автозагрузку"
echo "- Порт SSH разрешён в брандмауэре"
