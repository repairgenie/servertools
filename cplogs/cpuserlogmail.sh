#!/bin/bash

# Check if the username argument is provided
if [ -z "$1" ]; then
  echo "Error: Username required"
  echo "Usage: $0 <username>"
  exit 1
fi

# Define the username from the command line argument
USERNAME=$1

# Define log files to be collected
LOGFILES=("/home/$USERNAME/.cpanel/logs" "/home/$USERNAME/logs" "/home/$USERNAME/logs/.php.error.log" "/var/cpanel/bandwidth/$USERNAME" "/home/$USERNAME/.z-push/log" "/etc/apache2/logs/domlogs/$USERNAME")

# Check if the user exists
if ! id "$USERNAME" &>/dev/null; then
  echo "Error: Invalid username"
  exit 1
fi

# Define temp directory and name pattern for collected files
TEMPDIR="/tmp/"
NAMING_PATTERN=$(hostname)-$USERNAME-$(date +"%Y-%m-%d_%H:%M")

# Create temporary directories if they don't exist
mkdir -p $TEMPDIR/source_logs $TEMPDIR/temp2

# Loop over the logfiles to collect them in source_logs directory 
for LOGFILE in "${LOGFILES[@]}"; do
    # Check if the logfile is a directory
    if [ -d "$LOGFILE" ]; then
        echo "Processing directory: $LOGFILE"
        for FILE in "$LOGFILE"/*; do
            if [ -f "$FILE" ]; then
                cp "$FILE" $TEMPDIR/source_logs/$(basename "$FILE").log
                echo "Copied file: $FILE to $TEMPDIR/source_logs/$(basename "$FILE").log"
            else
                echo "Warning: Not a file or does not exist: $FILE"
            fi
        done
    elif [ -f "$LOGFILE" ]; then
        echo "Processing file: $LOGFILE"
        cp "$FILE" $TEMPDIR/source_logs/$(basename "$LOGFILE").log
        echo "Copied file: $LOGFILE to $TEMPDIR/source_logs/$(basename "$FILE").log"
    else
        echo "Warning: Log file or directory not found: $LOGFILE"
    fi
done

# Check if any files were copied
if [ -z "$(ls -A $TEMPDIR/source_logs)" ]; then
    echo "Error: No files were copied to the temporary source_logs directory. Exiting."
    exit 1
fi

# Compress collected logs into a single tar.gz file and store it in temp2 directory
GZFILE=$TEMPDIR/temp2/$NAMING_PATTERN.tar.gz
tar -czvf $GZFILE -C $TEMPDIR/source_logs .

# Check if tar command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create tar archive"
    exit 1
fi

# Define SMTP settings and email address
SMTPSERVER="smtp.server"  # replace with your SMTP server
SMTPPORT=587                    # replace with your SMTP port, usually 25 or 587 for TLS/STARTTLS or 465 for SSL/TLS
AUTHLOGIN="smtp user"                   # replace with your login if needed
AUTHPWD="smtp password"                     # replace with your password if needed
EMAILADDRESS="recipient@address.com"  # replace with recipient email address

# Build the message to be sent via email
SUBJECT="$(hostname) - $USERNAME Log Collection - $(date +"%Y-%m-%d %H:%M") - File size of gz: $(du -sh $GZFILE | cut -f1)"
BODY="Please find attached a log collection for review."

# Send the email via SMTP using sendEmail command line tool
sendEmail -f alerts@address.com -t $EMAILADDRESS -u "$SUBJECT" -m "$BODY" \
-a $GZFILE -s $SMTPSERVER:$SMTPPORT -xu $AUTHLOGIN -xp $AUTHPWD -v

# Clean up temporary files and directories except the tar.gz file
rm -rf $TEMPDIR/source_logs/*
find $TEMPDIR/temp2 -type f ! -name "$NAMING_PATTERN.tar.gz" -exec rm {} +

echo "Email with log file has been sent."
