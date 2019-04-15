#!/bin/bash

### Define scripts variables
#

TMP=/home/$USER/tmp
REF=/home/$USER/ref

shasum /etc/crontab > $TMP

### Execute script
#

## Check if a crontab reference already exist
if [ -f $REF ]; then

	## Check if the current reference is different
	if [ "$(diff $TMP $REF)" != "" ]; then

		## Send a notification mail to user root
		sudo sendmail root@$HOSTNAME < /home/$USER/cron/email.txt
		rm -f /home/$USER/tmp
		cp /home/$USER/ref /home/$USER/tmp
	fi
else
	shasum /etc/crontab > $REF
fi
