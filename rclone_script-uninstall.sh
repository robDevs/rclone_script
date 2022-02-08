#!/bin/bash


# define colors for output
NORMAL="\Zn"
BLACK="\Z0"
RED="\Z1"
GREEN="\Z2"
YELLOW="\Z3\Zb"
BLUE="\Z4"
MAGENTA="\Z5"
CYAN="\Z6"
WHITE="\Z7"
BOLD="\Zb"
REVERSE="\Zr"
UNDERLINE="\Zu"


backtitle="RCLONE_SCRIPT uninstaller (https://github.com/Jandalf81/rclone_script)"
logfile=~/scripts/rclone_script/rclone_script-uninstall.log

source ~/scripts/rclone_script/rclone_script.ini
oldRemote=""


##################
# WELCOME DIALOG #
##################
dialog \
	--stdout \
	--backtitle "${backtitle}" \
	--title "Welcome" \
	--colors \
	--no-collapse \
	--cr-wrap \
	--yesno \
		"\nThis script will ${RED}uninstall RCLONE_SCRIPT${NORMAL}. If you do this, your savefiles will no longer be synchronized! All changes made by RCLONE_SCRIPT installer will be reverted. This includes removal of RCLONE. Also, all configuration changes will be undone. Your local savefiles and savestates will be moved to the ROMS directory again.\nYour remote savefiles and statefiles will ${YELLOW}not${NORMAL} be removed.\n\nAre you sure you wish to continue?" \
	20 90 2>&1 > /dev/tty \
    || exit
	

####################
# DIALOG FUNCTIONS #
####################


# Build progress from array $STEPS()
# INPUT
#	$steps()
# OUTPUT
#	$progress
function buildProgress ()
{
	progress=""
	
	for ((i=0; i<=${#steps[*]}; i++))
	do
		progress="${progress}${steps[i]}\n"
	done
}

# Show Progress dialog
# INPUT
#	1 > Percentage to show in dialog
#	$backtitle
#	$progress
function dialogShowProgress ()
{
	local percent="$1"
	
	buildProgress
	
	clear
	clear
	
	echo "${percent}" | dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--backtitle "${backtitle}" \
		--title "Uninstaller" \
		--gauge "${progress}" 36 90 0 \
		2>&1 > /dev/tty
		
	sleep 1
}


##################
# STEP FUNCTIONS #
##################

# Initialize array $STEPS()
# OUTPUT
#	$steps()
function initSteps ()
{
	steps[1]="1. RCLONE"
	steps[2]="	1a. Remove RCLONE configuration			[ waiting...  ]"
	steps[3]="	1b. Remove RCLONE binary			[ waiting...  ]"
	steps[4]="2. RCLONE_SCRIPT"
	steps[5]="	2a. Remove RCLONE_SCRIPT files			[ waiting...  ]"
	steps[6]="	2b. Remove RCLONE_SCRIPT menu item		[ waiting...  ]"
	steps[7]="3. RUNCOMMAND"
	steps[8]="	3a. Remove call from RUNCOMMAND-ONSTART		[ waiting...  ]"
	steps[9]="	3b. Remove call from RUNCOMMAND-ONEND		[ waiting...  ]"
	steps[10]="4. Local SAVEFILE directory"
	steps[11]="	4a. Move savefiles to default			[ waiting...  ]"
	steps[12]="	4b. Remove local SAVEFILE directory		[ waiting...  ]"
	steps[13]="5. Configure RETROARCH"
	steps[14]="	5a. Reset local SAVEFILE directories		[ waiting...  ]"
	steps[15]="6 Finalizing"
	steps[16]="	6a. Remove UNINSTALL script			[ waiting...  ]"
}

# Update item of $STEPS() and show updated progress dialog
# INPUT
#	1 > Number of step to update
#	2 > New status for step
#	3 > Percentage to show in progress dialog
#	$steps()
# OUTPUT
#	$steps()
function updateStep ()
{
	local step="$1"
	local newStatus="$2"
	local percent="$3"
	local oldline
	local newline
	
	# translate and colorize $NEWSTATUS
	case "${newStatus}" in
		"waiting")     newStatus="[ ${NORMAL}WAITING...${NORMAL}  ]"  ;;
		"in progress") newStatus="[ ${NORMAL}IN PROGRESS${NORMAL} ]"  ;;
		"done")        newStatus="[ ${GREEN}DONE${NORMAL}        ]"  ;;
		"found")       newStatus="[ ${GREEN}FOUND${NORMAL}       ]"  ;;
		"not found")   newStatus="[ ${RED}NOT FOUND${NORMAL}   ]"  ;;
		"created")     newStatus="[ ${GREEN}CREATED${NORMAL}     ]"  ;;
		"failed")      newStatus="[ ${RED}FAILED${NORMAL}      ]"  ;;
		"skipped")     newStatus="[ ${YELLOW}SKIPPED${NORMAL}     ]"  ;;
		*)             newStatus="[ ${RED}UNDEFINED${NORMAL}   ]"  ;;
	esac
	
	# search $STEP in $STEPS
	for ((i=0; i<${#steps[*]}; i++))
	do
		if [[ ${steps[i]} =~ .*$step.* ]]
		then
			# update $STEP with $NEWSTATUS
			oldline="${steps[i]}"
			oldline="${oldline%%[*}"
			newline="${oldline}${newStatus}"
			steps[i]="${newline}"
			
			break
		fi
	done
	
	# show progress dialog
	dialogShowProgress ${percent}
}

# Show summary dialog
function dialogShowSummary ()
{
	dialog \
		--backtitle "${backtitle}" \
		--title "Summary" \
		--colors \
		--no-collapse \
		--cr-wrap \
		--yesno \
			"\n${GREEN}All done!${NORMAL}\n\nRCLONE_SCRIPT and its components have been removed. From now on, your saves and states will ${RED}NOT${NORMAL} be synchronized any longer. Your local savefiles have been moved to their default directories (inside each ROMS directory). Your remote files on\n	${YELLOW}${oldRemote}${NORMAL}\nhave ${GREEN}NOT${NORMAL} been removed.\n\nTo finish the uninstaller you should reboot your RetroPie now.\n\n${RED}Reboot RetroPie now?${NORMAL}" 25 90
	
	case $? in
		0) sudo shutdown -r now  ;;
	esac
}

#########################
# UNINSTALLER FUNCTIONS #
#########################

# Uninstaller
function uninstaller ()
{
	initSteps
	dialogShowProgress 0
	
	saveRemote
	
	1RCLONE
	2RCLONE_SCRIPT
	3RUNCOMMAND
	4LocalSAVEFILEDirectory
	5RetroArch
	6Finalize
	
	dialogShowSummary
}

function saveRemote ()
{
	# list all remotes and their type
	remotes=$(rclone listremotes -l)
	
	# get line with RETROPIE remote
	retval=$(grep -i "^retropie:" <<< ${remotes})

	remoteType="${retval#*:}"
	remoteType=$(echo ${remoteType} | xargs)
	
	oldRemote="retropie:${remotebasedir} (${remoteType})"
}

function 1RCLONE ()
{
	printf "$(date +%FT%T%:z):\t1RCLONE\tSTART\n" >> "${logfile}"
	
# 1a. Remove RCLONE configuration
	printf "$(date +%FT%T%:z):\t1aRCLONEconfiguration\tSTART\n" >> "${logfile}"
	updateStep "1a" "in progress" 0
	
	if [ -d ~/.config/rclone ]
	then
		{ #try
			sudo rm -r ~/.config/rclone >> "${logfile}" &&
			printf "$(date +%FT%T%:z):\t1aRCLONEconfiguration\tDONE\n" >> "${logfile}" &&
			updateStep "1a" "done" 8
		} || { #catch
			printf "$(date +%FT%T%:z):\t1aRCLONEconfiguration\tERROR\n" >> "${logfile}" &&
			updateStep "1a" "failed" 0 &&
			exit
		}
	else
		printf "$(date +%FT%T%:z):\t1aRCLONEconfiguration\tNOT FOUND\n" >> "${logfile}"
		updateStep "1a" "not found" 8
	fi
	
# 1b. Remove RCLONE binary
	printf "$(date +%FT%T%:z):\t1bRCLONEbinary\tSTART\n" >> "${logfile}"
	updateStep "1b" "in progress" 8
	
	if [ -f /usr/bin/rclone ]
	then
		{ #try
			sudo rm /usr/bin/rclone >> "${logfile}" &&
			printf "$(date +%FT%T%:z):\t1bRCLONEbinary\tDONE\n" >> "${logfile}" &&
			updateStep "1b" "done" 16
		} || { #catch
			printf "$(date +%FT%T%:z):\t1bRCLONEbinary\tERROR\n" >> "${logfile}" &&
			updateStep "1b" "failed" 8 &&
			exit
		}
	else
		printf "$(date +%FT%T%:z):\t1bRCLONEbinary\tNOT FOUND\n" >> "${logfile}"
		updateStep "1b" "not found" 16
	fi
	
	printf "$(date +%FT%T%:z):\t1RCLONE\tEND\n" >> "${logfile}"
}

function 2RCLONE_SCRIPT ()
{
	printf "$(date +%FT%T%:z):\t2RCLONE_SCRIPT\tSTART\n" >> "${logfile}"

# 2a. Remove RCLONE_SCRIPT
	printf "$(date +%FT%T%:z):\t2aRCLONE_SCRIPTfiles\tSTART\n" >> "${logfile}"
	updateStep "2a" "in progress" 32
	
	if [ -f ~/scripts/rclone_script/rclone_script.sh ]
	then
		{ # try
			sudo rm -f ~/scripts/rclone_script/rclone_script-install.* >> "${logfile}" &&
			sudo rm -f ~/scripts/rclone_script/rclone_script.* >> "${logfile}" &&
			printf "$(date +%FT%T%:z):\t2aRCLONE_SCRIPTfiles\tDONE\n" >> "${logfile}" &&
			updateStep "2a" "done" 40
		} || { # catch
			printf "$(date +%FT%T%:z):\t2aRCLONE_SCRIPTfiles\tERROR\n" >> "${logfile}" &&
			updateStep "2a" "failed" 32 &&
			exit
		}
	else
		printf "$(date +%FT%T%:z):\t2aRCLONE_SCRIPTfiles\tNOT FOUND\n" >> "${logfile}"
		updateStep "2a" "not found" 40
	fi
	
# 2b. Remove RCLONE_SCRIPT menu item
	printf "$(date +%FT%T%:z):\t2bRCLONE_SCRIPTMenuItem\tSTART\n" >> "${logfile}"
	updateStep "2b" "in progress" 40
	
	local found=0
		
	if [[ $(xmlstarlet sel -t -v "count(/gameList/game[path='./rclone_script-redirect.sh.sh'])" ~/.emulationstation/gamelists/retropie/gamelist.xml) -ne 0 ]]
	then
		found=$(($found + 1))
		
		printf "$(date +%FT%T%:z):\t2bRCLONE_SCRIPTMenuItem\tFOUND\n" >> "${logfile}"
		
		xmlstarlet ed \
			--inplace \
			--delete "//game[path='./rclone_script-redirect.sh']" \
			~/.emulationstation/gamelists/retropie/gamelist.xml
			
		printf "$(date +%FT%T%:z):\t2bRCLONE_SCRIPTMenuItem\tREMOVED\n" >> "${logfile}"
	else
		printf "$(date +%FT%T%:z):\t2bRCLONE_SCRIPTMenuItem\tNOT FOUND\n" >> "${logfile}"
	fi
	
	if [ -f ~/RetroPie/retropiemenu/rclone_script-redirect.sh ]
	then
		found=$(($found + 1))
		
		printf "$(date +%FT%T%:z):\t2bRCLONE_SCRIPTMenuItemScript\tFOUND\n" >> "${logfile}"
		
		sudo rm ~/RetroPie/retropiemenu/rclone_script-redirect.sh >> "${logfile}"
		sudo rm ~/scripts/rclone_script/rclone_script-menu.sh >> "${logfile}"
		
		printf "$(date +%FT%T%:z):\t2bRCLONE_SCRIPTMenuItemScript\tREMOVED\n" >> "${logfile}"
	else
		printf "$(date +%FT%T%:z):\t2bRCLONE_SCRIPTMenuItemScript\tNOT FOUND\n" >> "${logfile}"
	fi
	
	case $found in
		0) updateStep "2b" "not found" 48  ;;
		1) updateStep "2b" "done" 48  ;;
		2) updateStep "2b" "done" 48  ;;
	esac
	
	printf "$(date +%FT%T%:z):\t2RCLONE_SCRIPT\tDONE\n" >> "${logfile}"
}

function 3RUNCOMMAND ()
{
	printf "$(date +%FT%T%:z):\t3RUNCOMMAND\tSTART\n" >> "${logfile}"
	
# 3a. Remove call from RUNCOMMAND-ONSTART
	printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONSTART\tSTART\n" >> "${logfile}"
	updateStep "3a" "in progress" 48
	
	if [[ $(grep -c "~/scripts/rclone_script/rclone_script.sh" /opt/retropie/configs/all/runcommand-onstart.sh) -gt 0 ]]
	then
	{ #try
		sed -i "/~\/scripts\/rclone_script\/rclone_script.sh /d" /opt/retropie/configs/all/runcommand-onstart.sh &&
		printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONSTART\tDONE\n" >> "${logfile}" &&
		updateStep "3a" "done" 56
	} || { # catch
		printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONSTART\tERROR\n" >> "${logfile}" &&
		updateStep "3a" "failed" 48
	}
	else
		printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONSTART\tNOT FOUND\n" >> "${logfile}"
		updateStep "3a" "not found" 56
	fi
	
# 3b. Remove call from RUNCOMMAND-ONEND
	printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONEND\tSTART\n" >> "${logfile}"
	updateStep "3b" "in progress" 56
	
	if [[ $(grep -c "~/scripts/rclone_script/rclone_script.sh" /opt/retropie/configs/all/runcommand-onend.sh) -gt 0 ]]
	then
		{ #try
			sed -i "/~\/scripts\/rclone_script\/rclone_script.sh /d" /opt/retropie/configs/all/runcommand-onend.sh &&
			printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONEND\tDONE\n" >> "${logfile}" &&
			updateStep "3b" "done" 64
		} || { # catch
			printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONEND\tERROR\n" >> "${logfile}" &&
			updateStep "3b" "failed" 56
		}
	else
		printf "$(date +%FT%T%:z):\t3RUNCOMMAND-ONEND\tNOT FOUND\n" >> "${logfile}"
		updateStep "3b" "not found" 64
	fi
	
	printf "$(date +%FT%T%:z):\t3RUNCOMMAND\tDONE\n" >> "${logfile}"
}

function 4LocalSAVEFILEDirectory ()
{
	printf "$(date +%FT%T%:z):\t4LocalSAVEFILEDirectory\tSTART\n" >> "${logfile}"
	
# 4a. Move savefiles to default
	printf "$(date +%FT%T%:z):\t4a moveFilesToDefault\tSTART\n" >> "${logfile}"
	updateStep "4a" "in progress" 64
	
	if [ -d ~/RetroPie/saves ]
	then
		# start copy task in background, pipe numbered output into COPY.TXT and to LOGFILE
		$(cp -v -r ~/RetroPie/saves/* ~/RetroPie/roms | cat -n | tee copy.txt | cat >> "${logfile}") &
		
		# show content of COPY.TXT
		dialog \
			--backtitle "${backtitle}" \
			--title "Copying savefiles to default..." \
				--colors \
			--no-collapse \
			--cr-wrap \
			--tailbox copy.txt 40 120
			
		wait
		
		rm copy.txt
		
		updateStep "6a" "done" 72
	else
		printf "$(date +%FT%T%:z):\t4a moveFilesToDefault\tNOT FOUND\n" >> "${logfile}"
		updateStep "4a" "not found" 72
	fi
	
# 4b. Remove local SAVEFILE directory
	printf "$(date +%FT%T%:z):\t4b removeLocalSAVEFILEbasedir\tSTART\n" >> "${logfile}"
	updateStep "4b" "in progress" 72
	
	if [ -d ~/RetroPie/saves ]
	then
		# start remove task in background, pipe numbered output into DELETE.TXT and to LOGFILE
		$(sudo rm --recursive --force --verbose ~/RetroPie/saves | cat -n | tee delete.txt | cat >> "${logfile}") &
		
		# show content of REMOVE.TXT
		dialog \
			--backtitle "${backtitle}" \
			--title "Removing savefiles from local base dir..." \
			--colors \
			--no-collapse \
			--cr-wrap \
			--tailbox delete.txt 40 120
			
		wait
		
		rm delete.txt
		
		# check if that directory is shared
		local retval=$(grep -n "\[saves\]" /etc/samba/smb.conf)
		if [ "${retval}" != "" ]
		then
			# extract line numbers
			local lnStart="${retval%%:*}"
			local lnEnd=$(( $lnStart + 7 ))
			
			# remove network share
			sudo sed -i -e "${lnStart},${lnEnd}d" /etc/samba/smb.conf
			
			# restart SAMBA service
			sudo service smbd restart
			
			printf "$(date +%FT%T%:z):\t4b removeLocalSAVEFILEbasedir\tREMOVED network share\n" >> "${logfile}"
		fi	

		
		printf "$(date +%FT%T%:z):\t4b removeLocalSAVEFILEbasedir\tDONE\n" >> "${logfile}"
		updateStep "4b" "done" 80
	else
		printf "$(date +%FT%T%:z):\t4b removeLocalSAVEFILEbasedir\tNOT FOUND\n" >> "${logfile}"
		updateStep "4b" "skipped" 80
	fi
	
	printf "$(date +%FT%T%:z):\t4LocalSAVEFILEDirectory\tDONE\n" >> "${logfile}"
}

function 5RetroArch ()
{
	printf "$(date +%FT%T%:z):\t5RetroArch\tSTART\n" >> "${logfile}"

# 5a. Reset local SAVEFILE directories
	printf "$(date +%FT%T%:z):\t5a resetSAVEFILEdirectories\tSTART\n" >> "${logfile}"
	updateStep "5a" "in progress" 80
	
	local found=0
	
	# for each directory...
	for directory in /opt/retropie/configs/*
	do
		system="${directory##*/}"
		
		# skip system "all"
		if [ "${system}" == "all" ]
		then
			continue
		fi
		
		# check if there'a system specific RETROARCH.CFG
		if [ -f "${directory}/retroarch.cfg" ]
		then
			printf "$(date +%FT%T%:z):\t5a resetSAVEFILEdirectories\tFOUND retroarch.cfg for ${system}\n" >> "${logfile}"
			
			# check if RETROARCH.CFG contains SAVEFILE pointing to ~/RetroPie/saves/<SYSTEM>
			if [[ $(grep -c "^savefile_directory = \"~/RetroPie/saves/${system}\"" ${directory}/retroarch.cfg) -gt 0 ]]
			then
				printf "$(date +%FT%T%:z):\t5a resetSAVEFILEdirectories\tFOUND savefile_directory\n" >> "${logfile}"
				found=$(($found + 1))
				# replace parameter
				sed -i "/^savefile_directory = \"~\/RetroPie\/saves\/${system}\"/c\savefile_directory = \"default\"" ${directory}/retroarch.cfg
				printf "$(date +%FT%T%:z):\t5a resetSAVEFILEdirectories\tREPLACED savefile_directory\n" >> "${logfile}"
			else
				printf "$(date +%FT%T%:z):\t5a resetSAVEFILEdirectories\tNOT FOUND savefile_directory\n" >> "${logfile}"
			fi
			
			# check if RETROARCH.CFG contains SAVESTATE pointing to ~/RetroPie/saves/<SYSTEM>
			if [[ $(grep -c "^savestate_directory = \"~/RetroPie/saves/${system}\"" ${directory}/retroarch.cfg) -gt 0 ]]
			then
				printf "$(date +%FT%T%:z):\t5a resetSAVESTATEdirectories\tFOUND savestate_directory\n" >> "${logfile}"
				found=$(($found + 1))
				# replace parameter
				sed -i "/^savestate_directory = \"~\/RetroPie\/saves\/${system}\"/c\savestate_directory = \"default\"" ${directory}/retroarch.cfg
				printf "$(date +%FT%T%:z):\t5a resetSAVESTATEdirectories\tREPLACED savestate_directory\n" >> "${logfile}"
			else
				printf "$(date +%FT%T%:z):\t5a resetSAVESTATEdirectories\tNOT FOUND savestate_directory\n" >> "${logfile}"
			fi
		fi
	done

	printf "$(date +%FT%T%:z):\t5a resetSAVEFILEdirectories\tDINE\n" >> "${logfile}"
	if [[ $found -eq 0 ]]
	then
		updateStep "5a" "not found" 88
	else
		updateStep "5a" "done" 88
	fi

	printf "$(date +%FT%T%:z):\t5RetroArch\tDONE\n" >> "${logfile}"
}

function 6Finalize ()
{
	printf "$(date +%FT%T%:z):\t6Finalize\tSTART\n" >> "${logfile}"

# 6a. Remove UNINSTALL script
	printf "$(date +%FT%T%:z):\t6a removeUNINSTALLscript\tSTART\n" >> "${logfile}"
	updateStep "6a" "in progress" 88
	
	printf "$(date +%FT%T%:z):\t6a removeUNINSTALLscript\tDONE\n" >> "${logfile}"
	updateStep "6a" "done" 100
	
	printf "$(date +%FT%T%:z):\t6Finalize\tDONE\n" >> "${logfile}"
	
	# move LOGFILE to HOME
	mv ~/scripts/rclone_script/rclone_script-uninstall.log ~
	
	# remove RCLONE_SCRIPT directory
	rm -rf ~/scripts/rclone_script
}


########
# MAIN #
########

uninstaller
