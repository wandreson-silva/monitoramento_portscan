#!/bin/bash

# CONFIGURAÇÕES DO TELEGRAM
BOT_TOKEN="COLE_SEU_TOKEN_AQUI"
CHAT_ID="COLE_SEU_CHAT_ID_AQUI"

# Atualiza pacotes e instala dependências
echo "[+] Instalando dependências..."
sudo apt update && sudo apt install -y psad iptables-persistent curl

# Adiciona regras de log do iptables
echo "[+] Configurando iptables..."
sudo iptables -A INPUT -p tcp --syn -j LOG
sudo iptables -A FORWARD -p tcp --syn -j LOG
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null

# Cria script de alerta via Telegram
echo "[+] Criando script de alerta para Telegram..."
cat <<EOF | sudo tee /usr/local/bin/alerta_telegram.sh > /dev/null
#!/bin/bash
MENSAGEM="⚠️ Alerta: possível port scan detectado em \$(hostname) - \$(date)"
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \\
    -d chat_id="$CHAT_ID" \\
    -d text="\$MENSAGEM"
EOF

sudo chmod +x /usr/local/bin/alerta_telegram.sh

# Configura psad
echo "[+] Configurando psad..."
sudo sed -i "s/^EMAIL_ADDRESSES.*/EMAIL_ADDRESSES             root\@localhost;/g" /etc/psad/psad.conf
sudo sed -i "s/^HOSTNAME.*/HOSTNAME                    $(hostname);/g" /etc/psad/psad.conf
sudo sed -i "s/^ALERTING_METHODS.*/ALERTING_METHODS            email;/g" /etc/psad/psad.conf
sudo sed -i "s|^#EXTERNAL_CMD.*|EXTERNAL_CMD                /usr/local/bin/alerta_telegram.sh;|g" /etc/psad/psad.conf

# Reinicia o psad
echo "[+] Reiniciando psad..."
sudo psad --sig-update
sudo systemctl restart psad

echo "[✔] Instalação e configuração concluídas!"
echo "[📨] Agora faça um teste de escaneamento de outro IP com: nmap -sS SEU-IP"