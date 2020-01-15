Setup
1. Login as Root.
2. Create a file in /root with this code, such as clamav_cron.sh
3. Make the file executable:
    chmod +x /root/clamav_cron.sh
4. Setup the crontab with:
    15 0 * * * /root/clamav_cron.sh email1@domain.com > /dev/null 2>&1
5. Let 'er rip!

If you want to have multiple emails to send the summary to, the command would need to be altered to be:

    /root/clamav_cron.sh "email1@domain.com email2@domain.com"

Make sure you include the quotes around the email addresses to ensure they're processed correctly.