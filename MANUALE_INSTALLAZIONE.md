# Manuale di installazione — Ubuntu Server + Hermes Agent

Questo manuale descrive, passo per passo, come trasformare un computer generico
(desktop o portatile, anche datato, con almeno 4 GB di RAM e una CPU x86_64)
in un piccolo "server AI personale" basato su **Ubuntu Server 24.04 LTS** e
**Hermes Agent**.

I comandi sono generici e vanno adattati sostituendo i placeholder tra `< >`:

| Placeholder      | Significato                                   | Esempio            |
|------------------|------------------------------------------------|--------------------|
| `<utente>`       | Nome dell'utente amministratore del sistema     | `marco`            |
| `<hostname>`     | Nome host della macchina                        | `hermes-server`    |
| `<ip-server>`    | Indirizzo IP del server sulla rete locale        | `192.168.1.50`     |
| `<percorso>`     | Percorso generico su filesystem                 | `/home/<utente>/agent-workspace` |

---

## Indice

1. [Requisiti](#1-requisiti)
2. [Creazione del supporto di installazione](#2-creazione-del-supporto-di-installazione)
3. [Configurazione BIOS/UEFI](#3-configurazione-biosuefi)
4. [Installazione di Ubuntu Server](#4-installazione-di-ubuntu-server)
5. [Primo avvio e aggiornamento del sistema](#5-primo-avvio-e-aggiornamento-del-sistema)
6. [Configurazione della tastiera (se necessario)](#6-configurazione-della-tastiera-se-necessario)
7. [Verifica di rete](#7-verifica-di-rete)
8. [SSH e accesso remoto](#8-ssh-e-accesso-remoto)
9. [Firewall (ufw)](#9-firewall-ufw)
10. [Risparmio energetico (TLP, opzionale per portatili)](#10-risparmio-energetico-tlp-opzionale-per-portatili)
11. [Installazione di Hermes Agent](#11-installazione-di-hermes-agent)
12. [Configurazione di Hermes Agent](#12-configurazione-di-hermes-agent)
13. [Hermes come servizio systemd (Gateway)](#13-hermes-come-servizio-systemd-gateway)
14. [Architettura di esecuzione e modello di sicurezza](#14-architettura-di-esecuzione-e-modello-di-sicurezza)
15. [Docker (opzionale)](#15-docker-opzionale)
16. [Tailscale (opzionale, accesso remoto)](#16-tailscale-opzionale-accesso-remoto)
17. [Verifica finale del sistema](#17-verifica-finale-del-sistema)
18. [Appendice — comandi utili di manutenzione](#18-appendice--comandi-utili-di-manutenzione)

---

## 1. Requisiti

- Un computer x86_64 (desktop o portatile), anche datato: 4-8 GB di RAM e una
  CPU Celeron/Pentium/i3 sono sufficienti se Hermes Agent userà modelli via API
  cloud (OpenAI, OpenRouter, Anthropic, ecc.) e non modelli locali di grandi
  dimensioni.
- Una chiavetta USB da almeno 8 GB.
- Un secondo computer per scaricare l'immagine ISO e creare la chiavetta.
- Una connessione di rete (cavo Ethernet consigliato per l'installazione).
- Accesso all'alimentazione elettrica continua, se la macchina resterà accesa
  come server.

> Se il computer verrà usato **solo** come agente AI/server (nessun uso da
> desktop quotidiano), l'installazione consigliata è **Ubuntu Server 24.04
> LTS**, senza interfaccia grafica: consuma meno RAM, ha meno processi attivi,
> aggiornamenti più rapidi e maggiore stabilità per un uso 24/7.

---

## 2. Creazione del supporto di installazione

1. Scarica l'immagine ufficiale **Ubuntu Server 24.04 LTS** (architettura
   64-bit AMD64) dal sito ufficiale Ubuntu.
2. Scarica uno strumento per creare chiavette avviabili (es. Rufus su Windows,
   `dd` o balenaEtcher su Linux/macOS).
3. Inserisci la chiavetta USB e crea il supporto con questi parametri:
   - Schema di partizione: **GPT**
   - Sistema di destinazione: **UEFI** (non modalità CSM/Legacy)
   - Immagine: il file ISO di Ubuntu Server scaricato

Se il computer ha attualmente un altro sistema operativo (es. Windows) e vuoi
evitare problemi di avvio dalla USB:

```bash
# Da eseguire nell'altro sistema operativo, se è Windows,
# per disattivare ibernazione e Fast Startup prima di riavviare
powercfg /h off
```

---

## 3. Configurazione BIOS/UEFI

1. Spegni completamente il computer.
2. Inserisci la chiavetta USB di installazione.
3. Accendi il computer e premi ripetutamente il tasto di accesso al
   BIOS/Boot Menu. I tasti più comuni sono (variano da produttore a
   produttore): `ESC`, `F2`, `F7`, `F12`, `DEL`.
4. Nel BIOS/UEFI verifica/imposta:
   - **Secure Boot**: Disabled (se l'installazione lo richiede)
   - **Boot Mode**: UEFI abilitato, Legacy/CSM disabilitato
   - **USB Boot**: abilitato
5. Salva le impostazioni e riavvia selezionando la chiavetta USB come
   dispositivo di avvio.

---

## 4. Installazione di Ubuntu Server

Dal menu di avvio della chiavetta, avvia il programma di installazione e segui
questi criteri:

- **Lingua e tastiera**: seleziona quelle desiderate.
- **Componenti opzionali durante l'installazione**:
  - ✅ Installa **OpenSSH Server** (fondamentale per amministrare la macchina
    da remoto)
  - ❌ Non installare Docker in questa fase (verrà installato dopo, in modo
    controllato)
  - ❌ Non installare Kubernetes o altri servizi non necessari
- **Partizionamento**: per un utilizzo semplice, usa l'opzione guidata
  "Usa l'intero disco" (*Guided – Use Entire Disk*), che crea automaticamente
  la partizione EFI e la partizione di root. Non è necessario creare
  partizioni separate per un caso d'uso standard.
- **Utente amministratore**: crea l'utente che utilizzerai per amministrare il
  sistema (es. `<utente>`), impostando nome macchina (`<hostname>`) e una
  password sicura, che dovrai annotare in un luogo affidabile.

Al termine dell'installazione, rimuovi la chiavetta USB e riavvia.

---

## 5. Primo avvio e aggiornamento del sistema

Accedi con l'utente creato in fase di installazione (da tastiera/monitor
collegati oppure via SSH, vedi [Sezione 8](#8-ssh-e-accesso-remoto)) ed esegui:

```bash
sudo apt update
sudo apt upgrade -y
```

Installa alcuni strumenti di base utili all'amministrazione del sistema:

```bash
sudo apt install -y curl git htop tmux unzip xz-utils
```

---

## 6. Configurazione della tastiera (se necessario)

Se noti che i tasti producono caratteri sbagliati (es. premendo il tasto
fisico `[` ottieni un carattere accentato), verifica il layout effettivo prima
di modificare qualunque configurazione:

```bash
# Test temporaneo: applica il layout US e prova il tasto interessato
sudo loadkeys us

# Test temporaneo: applica il layout italiano e prova lo stesso tasto
sudo loadkeys it
```

Confronta i due risultati con quanto ti aspetti dalla tastiera fisica, quindi
imposta il layout corretto in modo permanente modificando il file di
configurazione:

```bash
sudo nano /etc/default/keyboard
```

Esempio di contenuto (adatta `XKBLAYOUT` al layout corretto, `us` oppure `it`):

```
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
```

Applica la configurazione e riavvia:

```bash
sudo setupcon
sudo reboot
```

Dopo il riavvio, verifica che la configurazione sia quella attesa:

```bash
cat /etc/default/keyboard
```

Comandi diagnostici utili in caso di problemi persistenti:

```bash
sudo systemctl status keyboard-setup --no-pager
sudo debconf-show keyboard-configuration
sudo dpkg-reconfigure keyboard-configuration
sudo systemctl restart keyboard-setup
```

> Nota: `sudo localectl set-keymap it` può restituire `Access denied` su
> Ubuntu Server perché `systemd-localed` potrebbe non essere attivo. In quel
> caso usa il metodo basato su `/etc/default/keyboard` mostrato sopra.

---

## 7. Verifica di rete

```bash
ip a                 # Visualizza interfacce di rete e indirizzi IP
hostname -I          # Mostra rapidamente gli IP del server
ping -c 4 <ip>       # Verifica la connettività verso un host/gateway
```

Annota l'indirizzo IP del server: ti servirà per connetterti via SSH da un
altro computer.

---

## 8. SSH e accesso remoto

Se non è stato installato durante il setup iniziale (Sezione 4), installa il
server SSH:

```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

Da un altro computer sulla stessa rete puoi quindi collegarti con:

```bash
ssh <utente>@<ip-server>
```

---

## 9. Firewall (ufw)

Controlla lo stato del firewall e apri la porta necessaria per SSH:

```bash
sudo ufw status
sudo ufw allow ssh
```

Se in seguito esporrai altri servizi (es. un server web), ricordati di aprire
anche le relative porte con `sudo ufw allow <porta>/tcp`.

---

## 10. Risparmio energetico (TLP, opzionale per portatili)

Se il sistema gira su un portatile e vuoi ridurre i consumi:

```bash
sudo apt install -y tlp
sudo systemctl enable tlp
sudo systemctl start tlp
```

---

## 11. Installazione di Hermes Agent

Installa le dipendenze minime richieste dall'installer:

```bash
sudo apt update
sudo apt install -y git curl xz-utils
```

Esegui lo script ufficiale di installazione di Hermes Agent (configura
automaticamente Python, Node.js e le altre dipendenze necessarie):

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

Ricarica la shell e verifica l'installazione:

```bash
source ~/.bashrc
hermes --version
hermes --help
```

Configura il provider AI (es. OpenAI, Anthropic, OpenRouter):

```bash
hermes setup
# oppure, per scegliere/cambiare solo il modello
hermes model
```

### 11.1 Integrazione e verifica con Ollama (Modelli Locali)

Se Hermes Agent è stato configurato per utilizzare **Ollama** come provider di modelli locali:

1. **Verifica dello stato del servizio Ollama sul server**:
   ```bash
   systemctl status ollama             # Controlla se il servizio Ollama è attivo
   ollama list                          # Elenca i modelli scaricati localmente
   ```

2. **Verifica del modello attivo in Hermes**:
   ```bash
   hermes model                         # Mostra e seleziona il modello corrente
   hermes config                        # Ispeziona la configurazione completa
   ```

3. **Verifica dell'esecuzione in tempo reale**:
   Quando invii un messaggio al bot su Telegram o via CLI, puoi verificare in tempo reale se Ollama sta elaborando la richiesta eseguendo sul server:
   ```bash
   ollama ps                            # Mostra i modelli attualmente caricati in RAM/VRAM
   journalctl --user -u hermes-gateway.service -f   # Segue i log del gateway in tempo reale
   ```

---

## 12. Configurazione di Hermes Agent

Per far lavorare Hermes come agente operativo sul sistema, ma con un
perimetro di lavoro definito, crea una directory dedicata:

```bash
mkdir -p ~/agent-workspace
cd ~/agent-workspace
pwd
```

Apri la configurazione di Hermes:

```bash
hermes config edit
```

Nella sezione `terminal:` imposta (adattando `cwd` al percorso reale):

```yaml
terminal:
  backend: local
  cwd: /home/<utente>/agent-workspace
  timeout: 180
  home_mode: auto
  container_cpu: 1
  container_memory: 5120
  container_disk: 51200
  container_persistent: true
  docker_mount_cwd_to_workspace: false
```

`backend: local` significa che i comandi impartiti a Hermes vengono eseguiti
direttamente sul sistema, con gli stessi permessi dell'utente che lo esegue
(non in un container isolato). Per questo motivo, in una prima fase è
consigliabile **non** configurare una password sudo per Hermes, per evitare
di concedere privilegi amministrativi automatici senza supervisione.

Verifica la configurazione applicata:

```bash
hermes config
```

Esegui un primo test in sola lettura, chiedendo a Hermes di ispezionare il
sistema senza modificarlo:

```bash
hermes
```
> Prompt di esempio: *"Analizza il sistema Ubuntu su cui stai lavorando. Non
> modificare nulla. Dimmi versione Ubuntu e kernel, CPU, RAM, dischi,
> interfacce di rete, servizi systemd attivi, versioni di Python/Git/Docker/
> Node.js se installati."*

Altri comandi utili della CLI:

```bash
hermes --cli               # Avvia la CLI classica
hermes -z "PROMPT"         # Esecuzione one-shot, utile per script
hermes --safe-mode         # Modalità sicura per diagnosticare problemi
hermes backup              # Backup di configurazione e dati
hermes update               # Aggiorna Hermes all'ultima versione
```

---

## 13. Hermes come servizio systemd (Gateway)

Hermes Agent espone un servizio utente (`hermes-gateway.service`) gestito da
systemd. Comandi utili per ispezionarlo e personalizzarlo:

```bash
systemctl --user status hermes-gateway.service
systemctl --user cat hermes-gateway.service
```

Per rendere permanente, ad esempio, l'uso di una shell persistente, crea un
file di override senza modificare direttamente il servizio originale:

```bash
mkdir -p ~/.config/systemd/user/hermes-gateway.service.d

cat > ~/.config/systemd/user/hermes-gateway.service.d/terminal-persistent.conf <<'EOF'
[Service]
Environment="TERMINAL_LOCAL_PERSISTENT=true"
EOF

systemctl --user daemon-reload
systemctl --user restart hermes-gateway.service
```

Verifica che la variabile sia stata effettivamente applicata:

```bash
systemctl --user show hermes-gateway.service -p Environment --value
systemctl --user cat hermes-gateway.service | grep -n 'TERMINAL_LOCAL_PERSISTENT'
```

---

## 14. Architettura di esecuzione e modello di sicurezza

Comprendere l'architettura con cui Hermes Agent interagisce con il sistema operativo è fondamentale per configurare correttamente permessi e livelli di autonomia.

### 14.1 Architettura di esecuzione sull'host

Hermes Agent **non viene eseguito in un container isolato o in una sandbox Linux standard**, ma direttamente come processo utente sull'host Ubuntu Server:

```
Ubuntu Server (Host)
  │
  └── sshd / Terminal
        │
        └── bash (utente, es. UID 1000)
              │
              └── hermes agent
                    ├── Namespace host
                    ├── Seccomp = 0
                    ├── NoNewPrivs = 0
                    ├── Permessi filesystem utente
                    └── Rete dell'host
```

Ispezione dell'albero dei processi (`ps -u "$USER" -o pid,ppid,stat,etime,cmd`):
- Il processo Python di Hermes risiede direttamente nella sessione shell dell'utente host (`sshd-session -> bash -> hermes agent`).
- L'agente condivide le interfacce di rete, il filesystem e le unità systemd del sistema host senza isolamento del kernel (namespaces dell'host).

### 14.2 Modello di sicurezza a doppia barriera

L'accesso operativo di Hermes è regolato da due barriere indipendenti:

```
                 HERMES
                   │
          ┌────────▼────────┐
          │ Safety / Policy │  ← Barriera 1: Safety Hook Hermes (intercetta comandi)
          └────────┬────────┘
                   │
          ┌────────▼────────┐
          │ Linux UID 1000  │  ← Barriera 2: Permessi SO (sudo / polkit)
          └────────┬────────┘
                   │
             sudo/password
                   │
          ┌────────▼────────┐
          │      root       │
          └─────────────────┘
```

1. **Safety Hook di Hermes (Livello applicativo)**:
   - È un meccanismo di controllo interno dell'agente che può bloccare o filtrare preventivamente comandi rischiosi prima che vengano inviati alla shell Linux.
2. **Permessi del Sistema Operativo Linux (Livello kernel/OS)**:
   - Hermes opera con l'UID dell'utente che lo ha avviato (es. UID 1000).
   - Se l'utente appartiene al gruppo `sudo`, l'esecuzione di comandi amministrativi richiede l'autenticazione tramite password (`sudo: a password is required`), impedendo a Hermes escalation non supervisionate.

> **Nota**: Non confondere l'accesso a **LXD** con i privilegi root sull'host. Se l'utente appartiene al gruppo `lxd`, Hermes può creare e gestire container unprivileged senza elevation di privilegi sull'host Ubuntu primario.

### 14.3 Matrice delle capacità dell'agente

Di seguito è riportato lo stato effettivo delle capacità e dei controlli di Hermes sul server:

| Capacità | Stato | Descrizione / Note |
|---|---|---|
| Shell host reale | 🟢 Confermato | Processo eseguito direttamente nell'ambiente dell'host |
| Filesystem host | 🟢 Confermato | Accesso in lettura e scrittura nei limiti dei permessi dell'utente |
| Rete host | 🟢 Confermato | Interfacce di rete e socket dell'host direttamente accessibili |
| Interrogazione systemd | 🟢 Visibile | Ispezione di servizi e stato delle unità tramite `systemctl` |
| Isolamento (Seccomp / Namespaces) | 🟢 Nessun isolamento | Esecuzione come processo utente standard nell'ambiente host |
| LXD | 🟢 Disponibile | Creazione/gestione di container unprivileged (tramite gruppo `lxd`) |
| Gestione pacchetti APT | 🟢 Installato | Lettura policy e pacchetti; installazioni richiedono `sudo` |
| Autenticazione `sudo` | 🟡 Richiede password | Non è configurato NOPASSWD per default (`sudo -n id`) |
| Controlli Polkit | 🟡 `auth_admin` | Le azioni con privilegi richiedono autenticazione |
| Docker Engine | 🔴 Opzionale | Non installato di default; attivabile con `--with-docker` |
| Root autonomo sull'host | 🔴 Disabilitato | Hermes non può eseguire comandi root in autonomia |
| Safety Hook Hermes | ⚠️ Attivo | Filtro applicativo attivo sui comandi potenzialmente pericolosi |

### 14.4 Test diagnostico rapido delle capacità amministrative

Per verificare lo stato dell'autenticazione `sudo` e il comportamento del safety hook senza apportare modifiche al sistema, è possibile eseguire un test non distruttivo:

```bash
sudo -n id
```

Possibili esiti:
- **`sudo: a password is required`** (Esito standard): conferma che `sudo` richiede la password interattiva dell'utente e che NOPASSWD non è attivo.
- **`Command blocked...`**: il Safety Hook di Hermes ha intercettato e bloccato l'uso del comando `sudo`.
- **`uid=0(root) ...`**: i privilegi root non interattivi risultano già attivi per l'utente.

---

## 15. Docker (opzionale)

Se prevedi di far gestire container a Hermes (es. per isolare l'esecuzione di
comandi), installa Docker Engine seguendo il metodo ufficiale Docker per
Ubuntu, quindi verifica l'installazione:

```bash
docker version
docker ps
docker images
```

> Si consiglia di installare Docker **dopo** aver verificato che il resto del
> sistema funzioni correttamente, per non introdurre variabili multiple da
> diagnosticare insieme.

---

## 16. Tailscale (opzionale, accesso remoto)

Se vuoi raggiungere il server anche fuori dalla rete locale, in alternativa
al solo SSH via IP locale, puoi installare Tailscale (rete privata basata su
WireGuard) seguendo la guida ufficiale del progetto, e poi collegarti alla
tua rete Tailscale eseguendo l'autenticazione richiesta dal comando di setup.

---

## 17. Verifica finale del sistema

Prima di considerare l'installazione completa, raccogli le informazioni
principali sul sistema:

```bash
lsb_release -a           # Versione di Ubuntu
uname -r                 # Versione del kernel
lscpu                    # CPU e numero di core
free -h                  # RAM e swap
df -h                    # Dischi e spazio disponibile
ip a                     # Interfacce di rete
systemctl list-units --type=service --state=running   # Servizi attivi
python3 --version
git --version
node -v 2>/dev/null
docker --version 2>/dev/null
hermes --version
```

---

## 18. Appendice — comandi utili di manutenzione

| Comando | Descrizione |
|---|---|
| `sudo reboot` | Riavvia il server |
| `sudo poweroff` | Spegne il server |
| `sudo systemctl status <servizio>` | Verifica lo stato di un servizio |
| `journalctl -u <servizio> -f` | Segue in tempo reale i log di un servizio |
| `df -h` | Spazio disco disponibile |
| `htop` | Monitoraggio interattivo di CPU/RAM/processi |
| `sudo apt update && sudo apt upgrade -y` | Aggiorna i pacchetti di sistema |
| `hermes config` | Mostra la configurazione corrente di Hermes |
| `hermes update` | Aggiorna Hermes Agent |
| `hermes backup` | Crea un backup di configurazione/dati di Hermes |

> ⚠️ Comandi come `rm -rf`, `dd`, `mkfs`, `fdisk`, `parted`, modifiche a
> `/etc` o alle unità systemd sono potenzialmente distruttivi: eseguili solo
> dopo aver compreso esattamente il loro effetto, ed evita di farli eseguire
> automaticamente da un agente AI senza supervisione.
