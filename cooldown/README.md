# Cooldown Script - Process Monitor with Self-Contained Log Rotation

`cooldown.sh` is a powerful and flexible Bash script designed to monitor system processes and automatically terminate those that exceed predefined CPU and runtime thresholds. It includes comprehensive logging, automatic log rotation, and easily customizable exclusion lists to prevent essential system services from being terminated.

This script is ideal for system administrators of shared hosting environments (like those running cPanel or DirectAdmin) or any Linux server where it's crucial to prevent individual users or runaway processes from monopolizing system resources and causing performance degradation.

## Features

-   **Automatic Process Termination**: Kills processes that exceed both a CPU usage percentage and a maximum running time.
-   **Two-Tiered CPU Thresholds**: Uses two separate CPU thresholds for logging and killing, allowing you to monitor resource-intensive processes without necessarily terminating them.
-   **Comprehensive Exclusion Lists**: Easily exclude critical system users and processes to ensure server stability. Default lists for cPanel, DirectAdmin, and common services are included.
-   **Detailed Logging**:
    -   **Kill Log**: Records every process that is terminated.
    -   **Warn Log**: Logs processes that *would* have been killed but were on an exclusion list, helping you identify resource-intensive but essential services.
    -   **Info Log**: Captures processes that are high on CPU but haven't yet met the time limit for termination.
-   **Automatic Log Rotation**: The script automatically rotates logs daily, keeping the main log files clean and archiving old logs for historical analysis.

## Installation

1.  **Place the Script**:
    Copy the `cooldown.sh` script to a suitable location on your server. A common choice is `/usr/local/sbin/`:

        cp cooldown.sh /usr/local/sbin/cooldown.sh

2.  **Make it Executable**:
    Grant execute permissions to the script:

        chmod +x /usr/local/sbin/cooldown.sh

3.  **Initial Log Directory Setup**:
    The script will automatically create the necessary log directories (`/var/log/cooldown`, `/var/log/cooldown/warn`, `/var/log/cooldown/kill`) the first time it runs.

## How to Use

### Running Manually

To run the script manually for testing or a one-time check, execute it and send it to the background so it continues to run after you close your terminal:

    /usr/local/sbin/cooldown.sh &

### Running at Boot (Recommended)

For persistent monitoring, the best practice is to have the script start automatically on server boot. You can do this by adding it to the root user's crontab.

1.  Open the root crontab editor:

        crontab -e

2.  Add the following line at the end of the file. This will execute the script every time the server reboots:

        @reboot /usr/local/sbin/cooldown.sh &

3.  Save and close the file.

## Configuration

All configuration is done by editing the variables at the top of the `cooldown.sh` script.

### Customizing Exclusions

#### Excluding Users

The `EXCLUDED_USERS` variable is a space-separated list of usernames whose processes should never be killed. This is critical for protecting system services.

To add a user, simply add their username to the list. For example, to exclude a user named `app-user`:

    EXCLUDED_USERS="root mysql admin ... app-user"

#### Excluding Processes

The `EXCLUDED_PROCESSES_ARRAY` is an array of process names that should be ignored. The script matches any command that *starts with* an entry in this list.

To add a process, add its name to the array. For example, to exclude a custom backup script named `my-backup-script.sh`:

    EXCLUDED_PROCESSES_ARRAY=(
        # ... existing processes
        "my-backup-script.sh"
        "another-process"
    )

### Customizing Limit Values

-   `CPU_THRESHOLD1=20`
    -   **Purpose**: An informational threshold. A process exceeding this CPU percentage will be logged in `cooldown.log` but will **not** be killed unless it also exceeds `CPU_THRESHOLD2` and `MAX_RUNNING_TIME`.
    -   **Default**: 20%

-   `MAX_RUNNING_TIME=90`
    -   **Purpose**: The maximum time in seconds a process can run *while also exceeding `CPU_THRESHOLD2`*.
    -   **Default**: 90 seconds

-   `CPU_THRESHOLD2=30`
    -   **Purpose**: The "kill" threshold. A process will be terminated if its CPU usage is above this percentage **AND** its runtime is greater than `MAX_RUNNING_TIME`.
    -   **Default**: 30%

## Logging Features and Strategies

The script's logging system is designed to give you a clear view of your server's process behavior. All logs are stored in `/var/log/cooldown/`.

### Log Files Explained

-   **Main Log**: `/var/log/cooldown/cooldown.log`
    -   Contains informational messages about processes that have crossed `CPU_THRESHOLD1` but are not yet eligible for termination.
    -   Also contains the "KILLING" messages for terminated processes.
    -   This is the primary, real-time log.

-   **Warn Log**: `/var/log/cooldown/cooldown-warn.log`
    -   This is one of the most useful logs for tuning your server.
    -   It records processes that met the criteria for termination (`CPU_THRESHOLD2` and `MAX_RUNNING_TIME`) but were **spared** because their user or process name was on an exclusion list.

-   **Kill Log (Archived)**: `/var/log/cooldown/kill/cooldown-YYYY-MM-DD.log`
    -   Every day, the main `cooldown.log` is moved into this directory and renamed with the previous day's date.
    -   This directory contains the historical record of all processes that were actually killed.

-   **Warn Log (Archived)**: `/var/log/cooldown/warn/cooldown-warn-YYYY-MM-DD.log`
    -   Similarly, the `cooldown-warn.log` is rotated daily into this directory.
    -   This gives you a historical view of which excluded processes are consistently using high resources.

### Strategies for Using the Logs

#### Using the Warn Log to Identify System Problems

The "warn" log is your best tool for proactive system tuning.

-   **How to Analyze**: Regularly check the contents of `/var/log/cooldown/cooldown-warn.log`. Look for patterns.
    -   Is the `lfd` (Login Failure Daemon) process frequently appearing? Your server might be under a brute-force attack.
    -   Is `mysqld` or `mariadbd` often listed? This could indicate poorly optimized database queries from a user's application that need investigation.
    -   Is a web server process like `php-fpm` showing up? This might point to a specific website or script that is inefficient and needs to be optimized.

By seeing which *essential* services are running hot, you can investigate the root cause without destabilizing the server by killing them.

#### Using the Kill Log to Identify Repeat Offenders

The "kill" log archive (`/var/log/cooldown/kill/`) is your record of who is causing performance problems.

-   **How to Analyze**: Use command-line tools like `grep` and `awk` to parse these logs.
    -   **Find the most frequently killed users**:

            grep "KILLING" /var/log/cooldown/kill/*.log | awk '{print $9}' | sort | uniq -c | sort -nr

        This command will give you a sorted list of usernames and how many times their processes have been killed. A user at the top of this list is likely running abusive or poorly written scripts.

    -   **Find the most frequently killed process names**:

            grep "KILLING" /var/log/cooldown/kill/*.log | awk '{print $6}' | sort | uniq -c | sort -nr

        This helps you identify if a specific application or script (e.g., `php`, `python`, a specific cron job) is the common culprit across different users.

By identifying these repeat offenders, you can contact the user, investigate their files, or take other administrative actions to resolve the underlying issue.

## Safety First: The `kill` Command

By default, the `kill -9 "$pid"` command within the script is **commented out** for safety.

    # --- SAFETY: The kill command is commented out by default. ---
    # --- Review logs before enabling to ensure safe operation.  ---
    #
    # kill -9 "$pid"

It is highly recommended to run the script for a few days in this "log-only" mode first. Review the `cooldown.log` to see what *would* be killed. Once you are confident that the script is behaving as expected and not targeting essential processes, you can uncomment that line to enable termination.