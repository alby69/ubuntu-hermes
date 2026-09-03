#!/usr/bin/env bash
#
# install-server-hermes.sh
#
# Script di installazione/configurazione automatica per:
#   - Ubuntu Server (aggiornamento, strumenti base, SSH, firewall)
#   - Hermes Agent (installazione, workspace dedicato, servizio systemd)
#   - (opzionale) Docker
#   - (opzionale) TLP (risparmio energetico, utile su portatili)
#
# Pensato per essere ESEGUITO PIÙ VOLTE senza rompere nulla:
# ogni fase verifica lo stato attuale prima di agire (idempotenza).
#
# Uso:
#   sudo ./install-server-hermes.sh [opzioni]
#
# Opzioni:
#   --username <nome>     Utente per cui configurare Hermes (default: utente che ha lanciato sudo)
#   --hostname <nome>     Hostname da impostare sul sistema (opzionale)
#   --with-docker         Installa anche Docker Engine (metodo ufficiale get.docker.com)
#   --with-tlp            Installa e abilita TLP (consigliato su portatili)
#   --skip-hermes         Salta l'installazione/configurazione di Hermes Agent
#   --skip-firewall       Salta la configurazione di ufw
#   -h, --help            Mostra questo aiuto
#
# Esempi:
#   sudo ./install-server-hermes.sh
#   sudo ./install-server-hermes.sh --username marco --hostname hermes-server --with-docker --with-tlp
#
set -Eeuo pipefail

# ------------------------------------------------------------------
# Configurazione di base
# ------------------------------------------------------------------

LOG_FILE="/var/log/install-server-hermes.log"

USERNAME="${SUDO_USER:-${USER:-}}"
TARGET_HOSTNAME=""
WITH_DOCKER="no"
WITH_TLP="no"
SKIP_HERMES="no"
SKIP_FIREWALL="no"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    if [[ -w "$(dirname "$LOG_FILE")" || -w "$LOG_FILE" ]] 2>/dev/null; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

die() {
    echo "ERRORE: $*" >&2
    exit 1
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "Questo script deve essere eseguito con sudo (es. 'sudo $0')."
    fi
}

print_help() {
    sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
}

# ------------------------------------------------------------------
# Parsing argomenti
# ------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="${2:-}"; shift 2 ;;
        --hostname)
            TARGET_HOSTNAME="${2:-}"; shift 2 ;;
        --with-docker)
            WITH_DOCKER="yes"; shift ;;
        --with-tlp)
            WITH_TLP="yes"; shift ;;
        --skip-hermes)
            SKIP_HERMES="yes"; shift ;;
        --skip-firewall)
            SKIP_FIREWALL="yes"; shift ;;
        -h|--help)
            print_help; exit 0 ;;
        *)
            die "Opzione sconosciuta: $1 (usa --help per l'elenco delle opzioni)" ;;
    esac
done

require_root

if [[ -z "$USERNAME" ]]; then
    die "Impossibile determinare l'utente target. Rilancia con --username <nome>."
fi

if ! id "$USERNAME" &>/dev/null; then
    die "L'utente '$USERNAME' non esiste sul sistema. Crealo prima di rilanciare lo script."
fi

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
[[ -d "$USER_HOME" ]] || die "Home directory di '$USERNAME' non trovata ($USER_HOME)."

run_as_user() {
    sudo -u "$USERNAME" -H bash -lc "$*"
}

log "=== Avvio install-server-hermes.sh (utente target: $USERNAME) ==="

# ------------------------------------------------------------------
# Fase 1 — Hostname (opzionale)
# ------------------------------------------------------------------

if [[ -n "$TARGET_HOSTNAME" ]]; then
    current_hostname="$(hostnamectl --static 2>/dev/null || hostname)"
    if [[ "$current_hostname" != "$TARGET_HOSTNAME" ]]; then
        log "Fase 1: imposto hostname a '$TARGET_HOSTNAME' (era '$current_hostname')"
        hostnamectl set-hostname "$TARGET_HOSTNAME"
    else
        log "Fase 1: hostname già impostato a '$TARGET_HOSTNAME', nessuna modifica necessaria"
    fi
else
    log "Fase 1: hostname non specificato, salto"
fi

# ------------------------------------------------------------------
# Fase 2 — Aggiornamento sistema e strumenti di base
# ------------------------------------------------------------------

log "Fase 2: aggiornamento indice pacchetti e sistema"
apt update
apt upgrade -y

log "Fase 2: installazione strumenti di base (idempotente)"
apt install -y curl git htop tmux unzip xz-utils

# ------------------------------------------------------------------
# Fase 3 — SSH
# ------------------------------------------------------------------

log "Fase 3: verifica/installazione OpenSSH Server"
if ! dpkg -s openssh-server &>/dev/null; then
    apt install -y openssh-server
else
    log "Fase 3: openssh-server già installato"
fi

systemctl enable --now ssh
systemctl status ssh --no-pager || true

# ------------------------------------------------------------------
# Fase 4 — Firewall (ufw)
# ------------------------------------------------------------------

if [[ "$SKIP_FIREWALL" == "no" ]]; then
    log "Fase 4: configurazione firewall (ufw)"
    if ! command -v ufw &>/dev/null; then
        apt install -y ufw
    fi
    ufw allow ssh || true
    ufw status
else
    log "Fase 4: configurazione firewall saltata (--skip-firewall)"
fi

# ------------------------------------------------------------------
# Fase 5 — TLP (opzionale, risparmio energetico su portatili)
# ------------------------------------------------------------------

if [[ "$WITH_TLP" == "yes" ]]; then
    log "Fase 5: installazione e abilitazione TLP"
    if ! dpkg -s tlp &>/dev/null; then
        apt install -y tlp
    else
        log "Fase 5: tlp già installato"
    fi
    systemctl enable tlp
    systemctl start tlp
else
    log "Fase 5: TLP non richiesto (usa --with-tlp per abilitarlo)"
fi

# ------------------------------------------------------------------
# Fase 6 — Docker (opzionale)
# ------------------------------------------------------------------

if [[ "$WITH_DOCKER" == "yes" ]]; then
    log "Fase 6: installazione Docker Engine"
    if command -v docker &>/dev/null; then
        log "Fase 6: Docker risulta già installato, salto l'installazione"
    else
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
    fi

    if ! id -nG "$USERNAME" | grep -qw docker; then
        log "Fase 6: aggiungo '$USERNAME' al gruppo docker"
        usermod -aG docker "$USERNAME"
        log "Nota: sarà necessario un nuovo login dell'utente perché il gruppo abbia effetto."
    fi

    docker version || true
else
    log "Fase 6: Docker non richiesto (usa --with-docker per installarlo)"
fi

# ------------------------------------------------------------------
# Fase 7 — Hermes Agent
# ------------------------------------------------------------------

if [[ "$SKIP_HERMES" == "no" ]]; then
    log "Fase 7: installazione Hermes Agent per l'utente '$USERNAME'"

    apt install -y git curl xz-utils

    if run_as_user "command -v hermes" &>/dev/null; then
        log "Fase 7: Hermes Agent risulta già installato per '$USERNAME', salto l'installer"
    else
        log "Fase 7: eseguo l'installer ufficiale di Hermes Agent"
        run_as_user "curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
    fi

    log "Fase 7: verifica versione Hermes installata"
    run_as_user "source ~/.bashrc; hermes --version" || true

    # ------------------------------------------------------------------
    # Fase 8 — Workspace dedicato per Hermes
    # ------------------------------------------------------------------

    WORKSPACE_DIR="$USER_HOME/agent-workspace"
    log "Fase 8: creazione workspace dedicato in $WORKSPACE_DIR"
    run_as_user "mkdir -p '$WORKSPACE_DIR'"

    # ------------------------------------------------------------------
    # Fase 9 — Servizio systemd Hermes Gateway (shell persistente)
    # ------------------------------------------------------------------

    OVERRIDE_DIR="$USER_HOME/.config/systemd/user/hermes-gateway.service.d"
    OVERRIDE_FILE="$OVERRIDE_DIR/terminal-persistent.conf"

    log "Fase 9: configurazione override systemd per shell persistente Hermes"
    run_as_user "mkdir -p '$OVERRIDE_DIR'"

    if [[ -f "$OVERRIDE_FILE" ]] && grep -q "TERMINAL_LOCAL_PERSISTENT=true" "$OVERRIDE_FILE" 2>/dev/null; then
        log "Fase 9: override già presente e corretto, nessuna modifica necessaria"
    else
        cat > "$OVERRIDE_FILE" <<'EOF'
[Service]
Environment="TERMINAL_LOCAL_PERSISTENT=true"
EOF
        chown "$USERNAME:$USERNAME" "$OVERRIDE_FILE"
        log "Fase 9: override creato/aggiornato in $OVERRIDE_FILE"
    fi

    run_as_user "systemctl --user daemon-reload" || true
    run_as_user "systemctl --user restart hermes-gateway.service" || \
        log "Fase 9: impossibile riavviare hermes-gateway.service (potrebbe non essere ancora attivo, verificare manualmente)"

    log "Fase 9: promemoria configurazione manuale consigliata"
    log "  -> Esegui 'hermes setup' o 'hermes model' come utente '$USERNAME' per configurare il provider AI."
    log "  -> Esegui 'hermes config edit' per impostare 'terminal.cwd: $WORKSPACE_DIR' e 'terminal.backend: local'."
else
    log "Fase 7-9: installazione/configurazione Hermes saltata (--skip-hermes)"
fi

# ------------------------------------------------------------------
# Fase 10 — Verifiche finali
# ------------------------------------------------------------------

log "Fase 10: verifiche finali del sistema"

{
    echo "--- lsb_release ---"; lsb_release -a 2>/dev/null || true
    echo "--- kernel ---"; uname -r
    echo "--- cpu ---"; lscpu | head -5
    echo "--- memoria ---"; free -h
    echo "--- disco ---"; df -h /
    echo "--- rete ---"; ip -brief a
    echo "--- ssh ---"; systemctl is-active ssh || true
    echo "--- ufw ---"; ufw status || true
    command -v docker &>/dev/null && { echo "--- docker ---"; docker --version; }
    run_as_user "command -v hermes" &>/dev/null && { echo "--- hermes ---"; run_as_user "hermes --version"; }
} | tee -a "$LOG_FILE" 2>/dev/null || true

log "=== Installazione completata. Log completo in $LOG_FILE ==="
