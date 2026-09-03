# Ubuntu Server + Hermes Agent Setup

Questo repository contiene la documentazione e lo script di automazione per trasformare un computer generico (desktop o portatile, anche datato con architettura x86_64 e almeno 4 GB di RAM) in un **server AI personale** basato su **Ubuntu Server 24.04 LTS** e **Hermes Agent**.

---

## 📋 Contenuto del Repository

- **[`MANUALE_INSTALLAZIONE.md`](MANUALE_INSTALLAZIONE.md)**: Guida dettagliata passo-passo che copre l'intero processo, dalla creazione della chiavetta USB avviabile, configurazione BIOS/UEFI, installazione di Ubuntu Server, gestione del layout tastiera, SSH, firewall (`ufw`), ottimizzazione energetica (`TLP`), fino all'installazione, architettura di esecuzione e modello di sicurezza a doppia barriera di Hermes Agent (gateway systemd, matrice capacità, Docker, Tailscale).
- **[`install-server-hermes.sh`](install-server-hermes.sh)**: Script Bash automatizzato ed **idempotente** (eseguibile più volte in sicurezza) che applica le configurazioni di base del server e installa Hermes Agent e le sue dipendenze.

---

## 💻 Requisiti di Sistema

- **Hardware**: Computer x86_64 (desktop o portatile) con almeno 4–8 GB di RAM e CPU x86_64.
- **Sistema Operativo Target**: Ubuntu Server 24.04 LTS (installato o da installare).
- **Connessione di rete**: Ethernet o Wi-Fi con accesso a Internet.
- **Credenziali**: Accesso con privilegi `sudo`.

---

## 🚀 Guida Rapida (Installazione Automatizzata)

Se hai già installato **Ubuntu Server 24.04 LTS**, puoi configurare l'ambiente ed installare Hermes Agent in modo rapido tramite lo script automatizzato `install-server-hermes.sh`.

### 1. Clona il repository o scarica lo script

```bash
git clone <url-repository>
cd <nome-repository>
```

### 2. Rendi lo script eseguibile

```bash
chmod +x install-server-hermes.sh
```

### 3. Esegui lo script con sudo

Esecuzione base (configura il sistema, SSH, firewall e installa Hermes Agent per l'utente corrente):

```bash
sudo ./install-server-hermes.sh
```

#### Opzioni e Flag disponibili

Lo script supporta diverse opzioni personalizzabili:

```bash
sudo ./install-server-hermes.sh [opzioni]
```

| Opzione | Descrizione |
|---|---|
| `--username <nome>` | Specifica l'utente target per cui configurare Hermes (default: utente che lancia `sudo`). |
| `--hostname <nome>` | Imposta l'hostname del sistema (opzionale). |
| `--with-docker` | Installa Docker Engine dal repository ufficiale e aggiunge l'utente al gruppo `docker`. |
| `--with-tlp` | Installa e abilita TLP per la gestione del risparmio energetico (consigliato per portatili). |
| `--skip-hermes` | Salta l'installazione e configurazione di Hermes Agent. |
| `--skip-firewall` | Salta la configurazione del firewall `ufw`. |
| `-h, --help` | Mostra l'aiuto in linea con l'elenco delle opzioni. |

**Esempio di comando avanzato:**

```bash
sudo ./install-server-hermes.sh --username marco --hostname hermes-server --with-docker --with-tlp
```

---

## 📖 Installazione Manuale Passo-Passo

Se preferisci eseguire l'installazione manualmente per comprendere ogni singolo passaggio o personalizzare la configurazione di rete, BIOS/UEFI e partizionamento, fai riferimento al **[Manuale di Installazione Dettagliato](MANUALE_INSTALLAZIONE.md)**.

Il manuale include:
1. Creazione chiavetta USB (Rufus / balenaEtcher / `dd`)
2. Configurazione BIOS/UEFI (Secure Boot, Boot Mode UEFI)
3. Partizionamento guidato e setup utente
4. Risoluzione dei problemi di layout tastiera (`/etc/default/keyboard`)
5. Configurazione SSH e Firewall (`ufw`)
6. Configurazione avanzata di Hermes Agent, `agent-workspace` e servizio systemd (`hermes-gateway.service`)
7. Architettura di esecuzione sull'host, modello di sicurezza a doppia barriera e matrice delle capacità
8. Integrazione opzionale con Docker e Tailscale per accesso remoto sicuro

---

## ⚙️ Configurazione Post-Installazione di Hermes Agent

Una volta completata l'installazione (automatica o manuale), procedi con la configurazione di Hermes Agent:

1. **Configura il provider AI** (es. OpenAI, Anthropic, OpenRouter):
   ```bash
   hermes setup
   # oppure per scegliere/cambiare modello:
   hermes model
   ```

2. **Verifica la directory di lavoro (workspace)**:
   Lo script crea una cartella dedicata `~/agent-workspace`. Assicurati che Hermes sia configurato per operare in questa directory modificando il file di configurazione:
   ```bash
   hermes config edit
   ```
   Nella sezione `terminal`:
   ```yaml
   terminal:
     backend: local
     cwd: /home/<tuo-utente>/agent-workspace
   ```

3. **Verifica lo stato del servizio Gateway**:
   ```bash
   systemctl --user status hermes-gateway.service
   ```

4. **Esegui un primo test di verifica**:
   ```bash
   hermes
   ```

---

## 🛠️ Manutenzione e Log

- **Log dell'installazione automatica**: consultabili in `/var/log/install-server-hermes.log`.
- **Aggiornamento di Hermes Agent**:
  ```bash
  hermes update
  ```
- **Backup della configurazione Hermes**:
  ```bash
  hermes backup
  ```
