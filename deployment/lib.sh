#!/bin/bash

## Color definition
#

END="\033[0m"
RED="\033[31m"
GRE="\033[32m"
CYA="\033[36m"

## Error check function
#

ch_err() {
	if [ $? -ne 0 ]; then
		echo -e "$RED[ERROR]$END$CYA script stopped !$END" && exit
	fi
}

ok_msg() {
	echo -e "$GRE[OK]$END$CYA $1 !$END"
}
