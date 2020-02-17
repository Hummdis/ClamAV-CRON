#!/usr/bin/env bash

# A standardized way to run ClamAV via CRON.

# Note: The preferred method is to run a scheduled Shellscan instead of ClamAV alone as Shellscan also runs maldet for enhnaced scans.
# For Exim, it's best to install the ClamAV Connector and enable the Exiscan in WHM's Exim Configuration.

####
# Setup
# 1. Login as Root.
# 2. Create a file in /root with this code, such as clamav_cron.sh
# 3. Make the file executable: chmod +x /root/clamav_cron.sh
# 4. Setup the crontab with:
#    15 0 * * * /root/clamav_cron.sh email1@domain.com > /dev/null 2>&1
# 5. Let 'er rip!
#
# If you want to have multiple emails to send the summary to, the command would need to be altered to be:
#
# /root/clamav_cron.sh "email1@domain.com email2@domain.com"
#
# Make sure you include the quotes!!
####

# If you don't want to automatically quarantine anything found, change this to 'false'.
QUARANTINE='true'

# Don't make edits below unless you know what you're doing.
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
VERSION=1.0.1
TIMESTAMP=$(date +%Y-%m-%H_%k:%M:%S)
MAIN_LOG="/var/log/clamav/clamav_summary-${TIMESTAMP}.txt"
EMAIL_MSG="The scheduled ClamAV scan is complete. Review the attached log summary for information.  This scans log file name is scanlog-${TIMESTAMP}.txt."
EMAIL_FROM="clamav@$(hostname)"
EMAIL_TO=${1}
DATE=$(date +%Y%m%d%H%M)

# Update ClamAV databases
echo "Updating ClamAV databases..."
freshclam > /dev/null 2>&1

for USER in $(awk '{print $2}' /etc/trueuserdomains)
do
	# Make the directory for logging if it doesn't exist.
	if [[ ! -e /home/$USER/quarantine/ ]]
	then
		mkdir -p /home/$USER/quarantine
	fi
	
	mkdir -p /home/$USER/quarantine/quarantine_$DATE
	
	echo -e "\nScanning $USER..."
	if [[ $QUARANTINE == 'true' ]]; then
		clamscan -ri --move=/home/$USER/quarantine/quarantine_$DATE/ --log=/home/$USER/quarantine/quarantine_$DATE/scanlog --max-dir-recursion=1000 --exclude="zip$" --exclude="tar.gz$" /home/$USER/
	else
		clamscan -ri --exclude-dir="^/sys" --log=/home/$USER/quarantine/quarantine_$DATE/scanlog --max-dir-recursion=1000 --exclude="zip$" --exclude="tar.gz$" /home/$USER/
	fi
	
	# Part 2, cron job to chown contents of folder to ensure cPanel readability
	echo "Setting $USER scanlog permissions..."
	chown -R $USER:$USER /home/$USER/quarantine/quarantine_$DATE/* 
	
	# Part 3, cron job to prone out log files older than 14 days
	echo "Cleaning up $USER scanlogs folder..."
	find -P /home/$USER/quarantine/quarantine_$DATE/. -type f -mtime '+14' -exec rm {} \;

	# Now, compile the summaries into a single log file to email to the desired email address.
	# The extra 'echo' statements are for formatting the email due to limitations with echo and the 'mail' command.
	echo -e "\n\nSummary for user ${USER}:\n" >> $MAIN_LOG
	tail -9 /home/$USER/quarantine/quarantine_$DATE/scanlog >> $MAIN_LOG

done

# Send the summary email.
echo -e "\n\nSending email to $1..."
echo "$EMAIL_MSG" | mail -a "$MAIN_LOG" -s "ClamAV Scan Complete" -r "$EMAIL_FROM" "$EMAIL_TO"

exit