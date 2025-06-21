#!/bin/bash

# Проверка наличия аргумента с IP-адресом
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

# Резервное копирование
sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
echo "Создана резервная копия: ${NETPLAN_FILE}.bak"

# Извлечение существующей конфигурации без enp0s8
grep -v '^\s*enp0s8:' "$NETPLAN_FILE" | grep -v -A 10 '^\s*enp0s8:' > /tmp/netplan.tmp

# Добавление нового блока для enp0s8
cat <<EOF >> /tmp/netplan.tmp

enp0s8:
  dhcp4: false
  addresses: [$IPADDR/24]
EOF

# Перемещение временного файла обратно
sudo mv /tmp/netplan.tmp "$NETPLAN_FILE"

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
echo "- SSH установлен, запущен и добавлен в автозагрузку"
echo "- Порт SSH разрешён в брандмауэре"
