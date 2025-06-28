#!/bin/bash

# Define log files to be collected
LOGFILES=("/usr/local/cpanel/logs/cphulkd_errors.log" 
"/usr/local/cpanel/logs/cphulkd.log" "/usr/local/cpanel/logs/cpwrapd_log" 
"/usr/local/cpanel/logs/error_log" "/usr/local/cpanel/logs/license_log" 
"/usr/local/cpanel/logs/login_log" "/usr/local/cpanel/logs/session_log" 
"/usr/local/cpanel/logs/setupdbmap_log" "/var/cpanel/accounting.log" 
"/usr/local/cpanel/logs/cpbackup" 
"/var/log/mysqld.log" "/var/log/messages" "/var/log/messages") 

# Define temp directory and name pattern for collected files
TEMPDIR="/tmp/"
NAMING_PATTERN=$(hostname)-$(date +%Y-%m-%d-%H:%M)

# Loop over the logfiles to collect them in temporary directory 
for LOGFILE in "${LOGFILES[@]}"; do
    cp $LOGFILE $TEMPDIR/$NAMING_PATTERN-$(basename $LOGFILE).log
done

# Compress collected files and get the size of the resulting gz file 
GZFILE=$NAMING_PATTERN.tar.gz
tar -czvf $TEMPDIR/$GZFILE $TEMPDIR/$NAMING_PATTERN-*
SIZE=$(ls -lh $TEMPDIR/$GZFILE | awk '{print $5}')

# Define SMTP settings and email address
SMTPSERVER="servername.serverdomain"  # replace with your SMTP server
SMTPPORT=587                    # replace with your SMTP port, usually 25 or 587 for TLS/STARTTLS or 465 for SSL/TLS
AUTHLOGIN="smtp user"                   # replace with your login if needed
AUTHPWD="enter your password"                     # replace with your password if needed
EMAILADDRESS="email@domain.com"  # replace with recipient email address

# Build the message to be sent via email
SUBJECT="$(hostname) - Log Collection - $DATE - $TIME - File size of gz: $SIZE"
BODY="Please find attached a log collection for review."
EMAILMESSAGE=$TEMPDIR/emailmessage.txt
echo "From: Log Collection <logs@example.com>" > $EMAILMESSAGE
echo "To: $EMAILADDRESS" >> $EMAILMESSAGE
echo "Subject: $SUBJECT" >> $EMAILMESSAGE
echo ""  >> $EMAILMESSAGE
echo "$BODY" >> $EMAILMESSAGE

# Send the email via SMTP using sendEmail command line tool
sendEmail -f alerts@address.com -t $EMAILADDRESS -u "$SUBJECT" -m "$BODY" \
-a $TEMPDIR/$GZFILE -s $SMTPSERVER:$SMTPPORT -xu $AUTHLOGIN -xp $AUTHPWD 
