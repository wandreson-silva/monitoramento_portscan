# monitoramento_portscan

# script automático que:
```text
1: Instala iptables-persistent e psad
2: Configura as regras do iptables para detectar escaneamento
3: Configura o psad com alerta por Telegram (você só precisa preencher TOKEN e CHAT_ID)
4: Salva e ativa as regras no boot
```

```ruby
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

```
# ▶️ Tornar executável e rodar:

```text
chmod +x monitoramento_portscan.sh
./monitoramento_portscan.sh
```
# ✅ O que você precisa fazer ANTES de rodar:

```text
Substituir COLE_SEU_TOKEN_AQUI e COLE_SEU_CHAT_ID_AQUI pelo token do seu bot Telegram e seu chat_id
(Opcional) configurar um e-mail se quiser receber alertas por e-mail também

```

# 1º Verifique se o psad está funcionando

```text
Execute:



sudo systemctl status psad

Depois:

sudo psad --Status

ou

sudo psad -S

Se aparecer que o daemon está ativo, ótimo.


# 2º Verifique se o iptables está gerando logs

Execute:

```ruby
sudo iptables -L -n -v
```
Você deverá ver regras semelhantes a:

```ruby
LOG  tcp  --  0.0.0.0/0   0.0.0.0/0   tcp flags:FIN,SYN,RST,ACK/SYN LOG
```
Se não aparecer, adicione:

```ruby
sudo iptables -A INPUT -p tcp --syn -j LOG --log-prefix "PSAD_SCAN: "
```

# 3º Veja se o Linux está registrando os logs

Em outra janela do terminal execute:

```ruby
sudo journalctl -kf

ou

sudo dmesg -w
```

Agora faça um escaneamento.

Se aparecer algo parecido com
```ruby
PSAD_SCAN: IN=eth0 OUT=
SRC=192.168.1.15
DST=192.168.1.20
PROTO=TCP
SPT=45231
DPT=22
```
está funcionando.


# 4º Faça um teste com Nmap

De outro computador da rede execute:

```ruby
nmap -Pn -sS IP_DO_SERVIDOR
```
Depois faça um teste mais agressivo:

```ruby
nmap -A -T4 IP_DO_SERVIDOR
```

Depois:

```ruby
sudo psad -S
```

Você deverá ver algo semelhante a:

Top scanning IP

192.168.1.15

Danger level: 5

# 5º Teste um port scan mais rápido
```ruby
nmap -sS -p- -T5 IP_DO_SERVIDOR
```
Esse normalmente gera diversos alertas.

# 6º Veja os logs do psad

```ruby
sudo tail -100 /var/log/psad/alert

ou

sudo cat /var/log/psad/status.out
```
# 7º Bloquear automaticamente o IP

O psad consegue bloquear o IP automaticamente.

Edite:

```ruby
sudo nano /etc/psad/psad.conf

Procure:

ENABLE_AUTO_IDS             N;

Troque para

ENABLE_AUTO_IDS             Y;

Depois:

AUTO_IDS_DANGER_LEVEL       3;
```
Assim, qualquer IP que atingir nível 3 será bloqueado.

Reinicie:
```ruby
sudo systemctl restart psad
```
# 8º Verifique se o bloqueio ocorreu

```ruby
sudo iptables -L -n
```
Você deverá ver uma regra semelhante a:

DROP all -- 192.168.1.15 0.0.0.0/0

```


