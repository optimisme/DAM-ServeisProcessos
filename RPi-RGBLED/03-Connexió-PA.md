# Per connectar al punt d'accés TP-LINK

Connecteu-vos a la PI a través de 'gencat_ENS_EDU':

```bash
ssh pi@dampiX.local
```

Crear l'arxiu de configuració WIFI:

```bash
sudo nano /etc/NetworkManager/system-connections/TP-LINK_90A9.nmconnection
```

Afegir aquesta configuració a l'arxiu:
```text
[connection]
id=TP-LINK_90A9
type=wifi
interface-name=wlan0

[wifi]
ssid=TP-LINK_90A9
mode=infrastructure

[wifi-security]
key-mgmt=wpa-psk
auth-alg=open
psk=96946633

[ipv4]
method=auto

[ipv6]
method=auto
```

Donar permissos:
```bash
sudo chmod 600 /etc/NetworkManager/system-connections/TP-LINK_90A9.nmconnection
```

Connectar la PI a través del punt d'accés:
```bash
sudo nmcli connection reload
sudo nmcli connection up TP-LINK_90A9
```

Connecteu-vos al Punt d'accés amb l'ordinador.
```text
TP-LINK_90A9
96946633
```

Connecteu-vos a la PI a través de 'TP-LINK_90A9':

```bash
ssh pi@dampiX.local
```

Si voleu que aquesta sigui la connexió per defecte:

```bash
sudo nmcli connection modify gencat_ENS_EDU connection.autoconnect no
sudo nmcli connection modify TP-LINK_90A9 connection.autoconnect yes
sudo reboot now
```

Per comprovar les xarxes:
```bash
nmcli dev wifi list
```

Per comprovar quina xarxa està configurada per defecte:
```bash
nmcli connection show --active
nmcli connection show TP-LINK_90A9
```

Ha de dir: **connection.autoconnect: yes**