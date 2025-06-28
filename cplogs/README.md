# cPanel Log Collector & Mailer Scripts

This repository contains two bash scripts designed to simplify the process of collecting and emailing cPanel log files from a server. One script gathers system-wide cPanel logs, while the other focuses on collecting logs for a specific cPanel user account.

## Prerequisites

Both scripts rely on the `sendEmail` command-line utility to dispatch emails with the log attachments. You must install this tool on your server before using the scripts.

You can typically install it using your system's package manager.

For CentOS/RHEL/AlmaLinux:

    sudo yum install sendemail

For Debian/Ubuntu:

    sudo apt-get install sendemail

---

## cplogmail.sh - System Log Collector

This script gathers a predefined list of general cPanel system logs, compresses them into a single archive, and emails it to a specified recipient.

### Purpose

To quickly package and send all major system-level cPanel logs for general server diagnostics or troubleshooting.

### Usage

The script does not require any command-line arguments.

1.  Make the script executable:

        chmod +x cplogmail.sh

2.  Run the script:

        ./cplogmail.sh

### Configuration

Before running, you must edit the script and configure the SMTP settings to match your environment.

-   `SMTPSERVER`: Your outgoing mail server (e.g., "smtp.yourprovider.com").
-   `SMTPPORT`: The port for your SMTP server (e.g., 587 for TLS, 465 for SSL).
-   `AUTHLOGIN`: The username for SMTP authentication.
-   `AUTHPWD`: The password for SMTP authentication.
-   `EMAILADDRESS`: The recipient's email address.

---

## cpuserlogmail.sh - Per-User Log Collector

This script gathers all relevant logs for a single, specified cPanel user, archives them, and emails the archive to a recipient. This is useful for troubleshooting issues related to a specific account.

### Purpose

To isolate and collect all relevant logs for a single cPanel user, including their cPanel access logs, error logs, and Apache domain logs.

### Usage

This script requires the cPanel **username** as a command-line argument.

1.  Make the script executable:

        chmod +x cpuserlogmail.sh

2.  Run the script, providing the username:

        ./cpuserlogmail.sh someuser

    Replace `someuser` with the actual cPanel username you wish to investigate. The script will exit if the username is not provided or is invalid.

### Configuration

Similar to the system script, you must edit the file to set up your SMTP credentials.

-   `SMTPSERVER`: Your outgoing mail server.
-   `SMTPPORT`: The SMTP port.
--   `AUTHLOGIN`: The SMTP username.
-   `AUTHPWD`: The SMTP password.
-   `EMAILADDRESS`: The email address where the log archive will be sent.

## How They Work

1.  **Define Logs**: Each script contains a `LOGFILES` array that lists the specific files and directories to be collected.
2.  **Collect**: The script copies all specified logs into a temporary directory (`/tmp/`) to avoid altering the original files. The `cpuserlogmail.sh` script is smart enough to copy the contents of directories listed in its log array.
3.  **Compress**: All collected log files are bundled into a single `.tar.gz` archive with a unique name based on the hostname, date, and (for the user script) the username.
4.  **Email**: Using the `sendEmail` tool and the configured SMTP settings, the script sends an email with the compressed log archive as an attachment.
5.  **Cleanup (`cpuserlogmail.sh` only)**: The user-specific script cleans up the individual log files it copied, leaving only the final `.tar.gz` archive in the `/tmp/temp2` directory.