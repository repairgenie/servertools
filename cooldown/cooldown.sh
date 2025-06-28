#!/bin/bash

# ====================================================================================
# Cooldown Script - Process Monitor with Self-Contained Log Rotation
#
# Monitors system processes and terminates those exceeding defined limits.
# Includes comprehensive exclusion lists and automatic daily log rotation.
#
# To run at boot, add to crontab: @reboot /path/to/cooldown.sh
# To run manually: ./cooldown.sh &
# ====================================================================================

# --- LOGGING & ROTATION SETUP ---
BASE_LOG_DIR="/var/log/cooldown"
WARN_DIR="$BASE_LOG_DIR/warn"
KILL_DIR="$BASE_LOG_DIR/kill"

# Create log directories if they don't exist
mkdir -p "$WARN_DIR" "$KILL_DIR"

# Set the primary log file paths
export LOGFILE="$BASE_LOG_DIR/cooldown.log"
export WARN_LOGFILE="$BASE_LOG_DIR/cooldown-warn.log"

# Redirect all script output to the main log file
# This must come AFTER defining LOGFILE
exec >> "$LOGFILE" 2>&1

# --- EXCLUSION LISTS ---
# List of excluded users for DirectAdmin, cPanel, and common system services.
EXCLUDED_USERS="root mysql admin diradmin mail mailman mailnull nobody named dovecot dovenull apache nginx daemon bin polkitd chrony dbus nscd systemd-network systemd-resolve systemd-timesync tss cpanel cpses cphulkd cpanelc+ bitninj+ wp-tool+"

# Excluded processes for various hosting environments.
EXCLUDED_PROCESSES_ARRAY=(
    # --- Security Services (BitNinja) ---
    "bitninja-agent" "bitninja-waf"
    # --- cPanel & WHM Core ---
    "cpaneld" "whostmgrd" "tailwatchd" "cphttpd" "cphulkd" "cpdavd" "cpsrvd" "queueprocd"
    "pkgacct" "upcp" "restartsrv_*"
    # --- DirectAdmin Core ---
    "directadmin" "dataskq"
    # --- Web Server ---
    "httpd" "nginx" "litespeed" "openlitespeed" "php-fpm"
    # --- Mail Services ---
    "exim" "dovecot" "lmtp" "imap" "pop3" "spamd" "spamd child" "clamd" "freshclam" "clambc"
    # --- DNS Server ---
    "named" "powerdns" "pdns_server"
    # --- Database ---
    "mysqld" "mariadbd" "postgres"
    # --- FTP Server ---
    "proftpd" "pure-ftpd"
    # --- System & Other ---
    "sshd" "cron" "crond" "nscd" "perl" "systemd" "journald" "logind" "networkd" "chronyd"
    "redis-server" "memcached"
)

# --- THRESHOLDS ---
CPU_THRESHOLD1=20
MAX_RUNNING_TIME=90
CPU_THRESHOLD2=30

# --- LOG ROTATION FUNCTION ---
rotate_logs() {
    local rotation_date_tag
    rotation_date_tag=$(date -d "yesterday" +"%Y-%m-%d")
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo "[$timestamp] --- Performing daily log rotation for $rotation_date_tag ---"

    # Rotate the main "kill" log
    if [ -f "$LOGFILE" ]; then
        mv "$LOGFILE" "$KILL_DIR/cooldown-$rotation_date_tag.log"
    fi

    # Rotate the "warn" log
    if [ -f "$WARN_LOGFILE" ]; then
        mv "$WARN_LOGFILE" "$WARN_DIR/cooldown-warn-$rotation_date_tag.log"
    fi

    # The exec redirection will automatically create new log files on the next write
    echo "[$timestamp] --- Log rotation complete. New logs started. ---"
}

# Initialize the date for the rotation check
last_rotation_date=$(date +"%Y-%m-%d")


# --- MAIN LOOP ---
while true; do
    # --- Daily Log Rotation Check ---
    current_date=$(date +"%Y-%m-%d")
    if [[ "$current_date" != "$last_rotation_date" ]]; then
        rotate_logs
        last_rotation_date="$current_date"
    fi

    # --- Process Monitoring ---
    ps -eo user,pid,pcpu,etime,command --no-headers | while read -r user pid pcpu etime command; do
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")

        IS_EXCLUDED=false
        EXCLUSION_REASON=""

        if [[ " $EXCLUDED_USERS " =~ " $user " ]]; then
            IS_EXCLUDED=true
            EXCLUSION_REASON="user '$user'"
        fi

        if [ -z "$command" ]; then
            process_name="[unknown_command]"
        else
            process_path=${command%% *}
            process_name=$(basename -- "$process_path")
        fi

        for excluded_item in "${EXCLUDED_PROCESSES_ARRAY[@]}"; do
            if [[ "$command" == "$excluded_item"* ]]; then
                IS_EXCLUDED=true
                if [ -n "$EXCLUSION_REASON" ]; then
                    EXCLUSION_REASON+=", and process name '$process_name'"
                else
                    EXCLUSION_REASON="process name '$process_name'"
                fi
                break
            fi
        done

        cpu_num=${pcpu%.*}
        elapsed_time=0
        if [[ $etime =~ ^([0-9]+)-([0-9]+):([0-9]+):([0-9]+)$ ]]; then
            elapsed_time=$(( (10#${BASH_REMATCH[1]}*86400) + (10#${BASH_REMATCH[2]}*3600) + (10#${BASH_REMATCH[3]}*60) + 10#${BASH_REMATCH[4]} ))
        elif [[ $etime =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
            elapsed_time=$(( (10#${BASH_REMATCH[1]}*3600) + (10#${BASH_REMATCH[2]}*60) + 10#${BASH_REMATCH[3]} ))
        elif [[ $etime =~ ^([0-9]+):([0-9]+)$ ]]; then
            elapsed_time=$(( (10#${BASH_REMATCH[1]}*60) + 10#${BASH_REMATCH[2]} ))
        elif [[ $etime =~ ^[0-9]+$ ]]; then
            elapsed_time=$((10#$etime))
        fi

        if (( cpu_num > CPU_THRESHOLD2 && elapsed_time >= MAX_RUNNING_TIME )); then
            exe_path=$(readlink -f /proc/$pid/exe 2>/dev/null || echo "[unknown_path]")

            if $IS_EXCLUDED; then
                echo "[$timestamp] WARNING: Process '$process_name' (PID: $pid) by user '$user' would be killed (CPU: $pcpu%, Time: $etime), but is IGNORED due to: $EXCLUSION_REASON." >> "$WARN_LOGFILE"
            else
                echo "[$timestamp] KILLING: Process '$process_name' (PID: $pid) by user '$user' (CPU: $pcpu%, Time: $etime) exceeded thresholds. Killing immediately."
                #
                # --- SAFETY: The kill command is commented out by default. ---
                # --- Review logs before enabling to ensure safe operation.  ---
                #
                # kill -9 "$pid"
            fi
        elif (( cpu_num > CPU_THRESHOLD1 )); then
            if ! $IS_EXCLUDED; then
                echo "[$timestamp] INFO: Process '$process_name' (PID: $pid) by user '$user' is high on CPU ($pcpu%) but under time limit ($etime). Not killing."
            fi
        fi
    done

    # Pause to prevent the script itself from using too much CPU
    sleep 5
done &