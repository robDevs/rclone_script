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


# global variables
url="https://raw.githubusercontent.com/KohlJary/rclone_script"
branch="master"

# configuration variables
remotebasedir=""
shownotifications=""

backtitle="RCLONE_SCRIPT installer (https://github.com/KohlJary/rclone_script)"
logfile=~/scripts/rclone_script/rclone_script-install.log


##################
# WELCOME DIALOG #
##################
dialog \
	--backtitle "${backtitle}" \
	--title "Welcome" \
	--colors \
	--no-collapse \
	--cr-wrap \
	--yesno \
		"\nThis script will configure RetroPie so that your savefiles and statefiles will be ${YELLOW}synchronized with a remote destination${NORMAL}. Several packages and scripts will be installed, see\n\n	https://github.com/Jandalf81/rclone_script/blob/master/ReadMe.md\n\nfor a rundown. In short, any time you ${GREEN}start${NORMAL} or ${RED}stop${NORMAL} a ROM the savefiles and savestates for that ROM will be ${GREEN}down-${NORMAL} and ${RED}uploaded${NORMAL} ${GREEN}from${NORMAL} and ${RED}to${NORMAL} a remote destination. To do so, RetroPie will be configured to put all savefiles and statefiles in distinct directories, seperated from the ROMS directories. This installer will guide you through the necessary steps. If you wish to see what exactly is done at each step, open a second console and execute\n	${YELLOW}tail -f ~/scripts/rclone_script/rclone_script-install.log${NORMAL}\n\nIf you already have some savefiles in the ROMS directory, you will need to ${YELLOW}move them manually${NORMAL} after installation. You can use the new network share\n	${YELLOW}\\\\$(hostname)\\saves${NORMAL}\nfor this.\n\nAre you sure you wish to continue?" \
	26 90 2>&1 > /dev/tty \
    || exit

	
####################
# DIALOG FUNCTIONS #
####################

# Warn the user if they are using the BETA branch
function dialogBetaWarning ()
{
	dialog \
		--backtitle "${backtitle}" \
		--title "Beta Warning" \
		--colors \
		--no-collapse \
		--cr-wrap \
		--yesno \
			"\n${RED}${UNDERLINE}WARNING!${NORMAL}\n\nYou are about to install a beta version!\nAre you ${RED}REALLY${NORMAL} sure you want to continue?" \
		10 50 2>&1 > /dev/tty \
    || exit
}

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
	
	echo "${percent}" | dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--backtitle "${backtitle}" \
		--title "Installer" \
		--gauge "${progress}" 36 90 0 \
		2>&1 > /dev/tty
		
	sleep 1
}

# Show summary dialog
function dialogShowSummary ()
{
	# list all remotes and their type
	remotes=$(rclone listremotes -l)
	
	# get line with RETROPIE remote
	retval=$(grep -i "^retropie:" <<< ${remotes})

	remoteType="${retval#*:}"
	remoteType=$(echo ${remoteType} | xargs)

	dialog \
		--backtitle "${backtitle}" \
		--title "Summary" \
		--colors \
		--no-collapse \
		--cr-wrap \
		--yesno \
			"\n${GREEN}All done!${NORMAL}\n\nFrom now on, all your saves and states will be synchronized each time you start or stop a ROM.\n\nAll systems will put their saves and states in\n	Local: \"${YELLOW}~/RetroPie/saves/<SYSTEM>${NORMAL}\"\n	Remote: \"${YELLOW}retropie:${remotebasedir}/<SYSTEM>${NORMAL}\" (${remoteType})\nIf you already have some saves in the ROM directories, you need to move them there manually now!  You can use the new network share\n	${YELLOW}\\\\$(hostname)\\saves${NORMAL}\nfor this. Afterward, you should ${red}reboot${NORMAL} your RetroPie. Then, you should start a full sync via\n	${YELLOW}RetroPie / RCLONE_SCRIPT menu / 1 Full sync${NORMAL}\n\nStart\n	${YELLOW}RetroPie / RCLONE_SCRIPT menu / 9 uninstall${NORMAL}\nto revert all changes and remove this script.\n\nTo finish the installer you should reboot your RetroPie now.\n\n${RED}Reboot RetroPie now?${NORMAL}" \
		28 90 2>&1 > /dev/tty
	
	case $? in
		0) sudo shutdown -r now  ;;
	esac
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
	steps[2]="	1a. Test for RCLONE binary			[ waiting...  ]"
	steps[3]="	1b. Download RCLONE binary			[ waiting...  ]"
	steps[4]="	1c. Test RCLONE remote				[ waiting...  ]"
	steps[5]="	1d. Create RCLONE remote			[ waiting...  ]"
	steps[6]="2. RCLONE_SCRIPT"
	steps[7]="	2a. Download RCLONE_SCRIPT files		[ waiting...  ]"
	steps[8]="	2b. Create RCLONE_SCRIPT menu item		[ waiting...  ]"
	steps[9]="	2c. Configure RCLONE_SCRIPT			[ waiting...  ]"
	steps[10]="3. RUNCOMMAND"
	steps[11]="	3a. Add call to RUNCOMMAND-ONSTART		[ waiting...  ]"
	steps[12]="	3b. Add call to RUNCOMMAND-ONEND		[ waiting...  ]"
	steps[13]="4. Local SAVEFILE directory"
	steps[14]="	4a. Check local base directory			[ waiting...  ]"
	steps[15]="	4b. Check local <SYSTEM> directories		[ waiting...  ]"
	steps[16]="5. Remote SAVEFILE directory"
	steps[17]="	5a. Check remote base directory			[ waiting...  ]"
	steps[18]="	5b. Check remote <SYSTEM> directories		[ waiting...  ]"
	steps[19]="6. Configure RETROARCH"
	steps[20]="	6a. Set local SAVEFILE directories		[ waiting...  ]"
	steps[21]="7. Finalizing"
	steps[22]="	7a. Save configuration				[ waiting...  ]"
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


#######################
# INSTALLER FUNCTIONS #
#######################


# Installer
function installer ()
{
	initSteps
	dialogShowProgress 0
	
	1RCLONE
	2RCLONE_SCRIPT
	3RUNCOMMAND
	4LocalSAVEFILEDirectory
	5RemoteSAVEFILEDirectory
	6ConfigureRETROARCH
	7Finalize
	
	dialogShowSummary
}

function 1RCLONE () 
{
# 1a. Testing for RCLONE binary
	updateStep "1a" "in progress" 0
	
	1aTestRCLONE
	if [[ $? -eq 0 ]]
	then
		updateStep "1a" "found" 5
		updateStep "1b" "skipped" 10
	else
		updateStep "1a" "not found" 5
		
# 1b. Getting RCLONE binary
		updateStep "1b" "in progress" 5
		
		1bInstallRCLONE
		if [[ $? -eq 0 ]]
		then
			updateStep "1b" "done" 10
		else
			updateStep "1b" "failed" 5
			exit
		fi
	fi
	
# 1c. Testing RCLONE configuration
	updateStep "1c" "in progress" 10
	
	1cTestRCLONEremote
	if [[ $? -eq 0 ]]
	then
		updateStep "1c" "found" 15
		updateStep "1d" "skipped" 20
	else
		updateStep "1c" "not found" 15
		
# 1d. Create RCLONE remote
		updateStep "1d" "in progress" 15
		1dCreateRCLONEremote
		updateStep "1d" "done" 20
	fi
}

# Checks if RCLONE is installed
# RETURN
# 	0 > RCLONE is installed
# 	1 > RCLONE is not installed
function 1aTestRCLONE ()
{
	printf "$(date +%FT%T%:z):\t1aTestRCLONE\tSTART\n" >> "${logfile}"
	
	if [ -f /usr/bin/rclone ]
	then
		printf "$(date +%FT%T%:z):\t1aTestRCLONE\tFOUND\n" >> "${logfile}"
		return 0
	else
		printf "$(date +%FT%T%:z):\t1aTestRCLONE\tNOT FOUND\n" >> "${logfile}"
		return 1
	fi
}

# Installs RCLONE by download
# RETURN
#	0 > RCLONE has been installed
#	1 > Error while installing RCLONE
function 1bInstallRCLONE ()
{
	printf "$(date +%FT%T%:z):\t1bInstallRCLONE\tSTART\n" >> "${logfile}"
	
	# TODO get RCLONE for 64bit
	{ # try
		# get binary
		wget -P ~ https://downloads.rclone.org/rclone-current-linux-arm.zip --append-output="${logfile}" &&
		unzip ~/rclone-current-linux-arm.zip -d ~ >> "${logfile}" &&
		
		cd ~/rclone-v* &&

		# move binary
		sudo mv rclone /usr/bin >> "${logfile}" &&
		sudo chown root:root /usr/bin/rclone >> "${logfile}" &&
		sudo chmod 755 /usr/bin/rclone >> "${logfile}" &&
		
		cd ~ &&
		
		# remove temp files
		rm ~/rclone-current-linux-arm.zip >> "${logfile}" &&
		rm -r ~/rclone-v* >> "${logfile}" &&
		
		printf "$(date +%FT%T%:z):\t1bInstallRCLONE\tDONE\n" >> "${logfile}" &&
		
		return 0
	} || { #catch
		printf "$(date +%FT%T%:z):\t1bInstallRCLONE\tERROR\n" >> "${logfile}" &&
		
		# remove temp files
		rm ~/rclone-current-linux-arm.zip >> "${logfile}" &&
		rm -r ~/rclone-v* >> "${logfile}" &&
		
		return 1
	}
}

# Checks if there's a RCLONE remote called RETROPIE
# RETURN
#	0 > remote RETROPIE has been found
#	1 > no remote RETROPIE found
function 1cTestRCLONEremote ()
{
	printf "$(date +%FT%T%:z):\t1cTestRCLONEremote\tSTART\n" >> "${logfile}"
	
	local remotes=$(rclone listremotes)
	
	local retval=$(grep -i "^retropie:" <<< ${remotes})
	
	if [ "${retval}" == "retropie:" ]
	then
		printf "$(date +%FT%T%:z):\t1cTestRCLONEremote\tFOUND\n" >> "${logfile}"
		return 0
	else
		printf "$(date +%FT%T%:z):\t1cTestRCLONEremote\tNOT FOUND\n" >> "${logfile}"
		return 1
	fi
}

# Tells the user to create a new RCLONE remote called RETROPIE
# RETURN
#	0 > remote RETROPIE has been created (no other OUTPUT possible)
function 1dCreateRCLONEremote ()
{
	printf "$(date +%FT%T%:z):\t1dCreateRCLONEremote\tSTART\n" >> "${logfile}"
	
	dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--backtitle "${backtitle}" \
		--title "Installer" \
		--msgbox "\nPlease create a new remote within RCLONE now. Name that remote ${RED}retropie${NORMAL}. Please consult the RCLONE documentation for further information:\n	https://www.rclone.org\n\nOpening RCLONE CONFIG now..." 20 50 \
		2>&1 > /dev/tty
		
	clear
	rclone config
	
	1cTestRCLONEremote
	if [[ $? -eq 1 ]]
	then
		dialog \
			--stdout \
			--colors \
			--no-collapse \
			--cr-wrap \
			--backtitle "${backtitle}" \
			--title "Installer" \
			--msgbox "\nNo remote ${RED}retropie${NORMAL} found.\nPlease try again." 20 50 \
		2>&1 > /dev/tty
			
		1dCreateRCLONEremote
	else
		printf "$(date +%FT%T%:z):\t1dCreateRCLONEremote\tFOUND\n" >> "${logfile}"
		return 0
	fi	
}

function 2RCLONE_SCRIPT ()
{
# 2a. Getting RCLONE_SCRIPT
	updateStep "2a" "in progress" 45
	
	2aGetRCLONE_SCRIPT
	if [[ $? -eq 0 ]]
	then
		updateStep "2a" "done" 50
	else
		updateStep "2a" "failed" 45
		exit
	fi

# 2b. Creating RCLONE_SCRIPT menu item
	updateStep "2b" "in progress" 50
	
	2bCreateRCLONE_SCRIPTMenuItem
	if [[ $? -eq 0 ]]
	then
		updateStep "2b" "done" 55
	else
		updateStep "2b" "failed" 50
		exit
	fi

# 2c. Configure RCLONE_SCRIPT
	updateStep "2c" "in progress" 55
	
	2cConfigureRCLONE_SCRIPT
	
	updateStep "2c" "done" 60
}

# Gets RCLONE_SCRIPT
# RETURN
#	0 > downloaded successfully
#	1 > errors while downloading
function 2aGetRCLONE_SCRIPT ()
{
	printf "$(date +%FT%T%:z):\t2aGetRCLONE_SCRIPT\tSTART\n" >> "${logfile}"
	
	# create directory if necessary
	if [ ! -d ~/scripts/rclone_script ]
	then
		mkdir ~/scripts/rclone_script >> "${logfile}"
	fi
	
	{ #try
		# get script files
		wget -N -P ~/scripts/rclone_script ${url}/${branch}/rclone_script.sh --append-output="${logfile}" &&
		wget -N -P ~/scripts/rclone_script ${url}/${branch}/rclone_script-menu.sh --append-output="${logfile}" &&
		wget -N -P ~/scripts/rclone_script ${url}/${branch}/rclone_script-uninstall.sh --append-output="${logfile}" &&
		
		# change mod
		chmod +x ~/scripts/rclone_script/rclone_script.sh >> "${logfile}" &&
		chmod +x ~/scripts/rclone_script/rclone_script-menu.sh >> "${logfile}" &&
		chmod +x ~/scripts/rclone_script/rclone_script-uninstall.sh >> "${logfile}" &&
		
		printf "$(date +%FT%T%:z):\t2aGetRCLONE_SCRIPT\tDONE\n" >> "${logfile}" &&
		
		return 0
	} || { # catch
		printf "$(date +%FT%T%:z):\t2aGetRCLONE_SCRIPT\tERROR\n" >> "${logfile}" &&
		
		return 1
	}
}

# Creates a menu item for RCLONE_SCRIPT in RetroPie menu
# RETURN
#	0 > menu item has been found or created
#	1 > error while creating menu item
function 2bCreateRCLONE_SCRIPTMenuItem ()
{
	printf "$(date +%FT%T%:z):\t2bCreateRCLONE_SCRIPTMenuItem\tSTART\n" >> "${logfile}"
	
	# create redirect script
	printf "#!/bin/bash\n~/scripts/rclone_script/rclone_script-menu.sh" > ~/RetroPie/retropiemenu/rclone_script-redirect.sh
	chmod +x ~/RetroPie/retropiemenu/rclone_script-redirect.sh
	
	# check if menu item exists
	if [[ $(xmlstarlet sel -t -v "count(/gameList/game[path='./rclone_script-redirect.sh'])" ~/.emulationstation/gamelists/retropie/gamelist.xml) -eq 0 ]]
	then
		printf "$(date +%FT%T%:z):\t2bCreateRCLONE_SCRIPTMenuItem\tNOT FOUND\n" >> "${logfile}"
			
		xmlstarlet ed \
			--inplace \
			--subnode "/gameList" --type elem -n game -v ""  \
			--subnode "/gameList/game[last()]" --type elem -n path -v "./rclone_script-redirect.sh" \
			--subnode "/gameList/game[last()]" --type elem -n name -v "RCLONE_SCRIPT menu" \
			--subnode "/gameList/game[last()]" --type elem -n desc -v "Launches a menu allowing you to start a full sync, configure RCLONE_SCRIPT or even uninstall it" \
			~/.emulationstation/gamelists/retropie/gamelist.xml
		
		if [[ $? -eq 0 ]]
		then
			printf "$(date +%FT%T%:z):\t2bCreateRCLONE_SCRIPTMenuItem\tCREATED\n" >> "${logfile}"
			return 0
		else
			printf "$(date +%FT%T%:z):\t2bCreateRCLONE_SCRIPTMenuItem\tERROR\n" >> "${logfile}"
			return 1
		fi
	else
		printf "$(date +%FT%T%:z):\t2bCreateRCLONE_SCRIPTMenuItem\tFOUND\n" >> "${logfile}"
		return 0
	fi
}

# Gets user input to configure RCLONE_SCRIPT
function 2cConfigureRCLONE_SCRIPT ()
{
	printf "$(date +%FT%T%:z):\t2cConfigureRCLONE_SCRIPT\tSTART\n" >> "${logfile}"
	
	remotebasedir=$(dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--no-cancel \
		--backtitle "${backtitle}" \
		--title "Remote base directory" \
		--inputbox "\nPlease name the directory which will be used as your ${YELLOW}remote base directory${NORMAL}. If necessary, this directory will be created.\n\nExamples:\n* RetroArch\n* mySaves/RetroArch\n\n" 18 40 "RetroArch" 
		)
		
	dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--backtitle "${backtitle}" \
		--title "Notifications" \
		--yesno "\nDo you wish to see ${YELLOW}notifications${NORMAL} whenever RCLONE_SCRIPT is synchronizing?" 18 40
		
	case $? in
		0) shownotifications="TRUE"  ;;
		1) shownotifications="FALSE"  ;;
		*) shownotifications="FALSE"  ;;
	esac
	
	choice=$(dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--backtitle "${backtitle}" \
		--title "Needed connection" \
		--ok-label "Select" \
		--no-cancel \
		--menu "\nPlease select which type of connection will be needed for your configured remote" 20 50 5 \
			0 "Internet access" \
			1 "LAN / WLAN connection only"
		)
	
	neededConnection=${choice}
	
	printf "$(date +%FT%T%:z):\t2cConfigureRCLONE_SCRIPT\tDONE\n" >> "${logfile}"
}

function 3RUNCOMMAND ()
{
# 3a. RUNCOMMAND-ONSTART
	updateStep "3a" "in progress" 60
	
	3aRUNCOMMAND-ONSTART
	case $? in
		0) updateStep "3a" "found" 65  ;;
		1) updateStep "3a" "created" 65  ;;
	esac
	
# 3b. RUNCOMMAND-ONEND
	updateStep "3b" "in progress" 65
	
	3aRUNCOMMAND-ONEND
	case $? in
		0) updateStep "3b" "found" 70  ;;
		1) updateStep "3b" "created" 70  ;;
	esac
}

# Checks call of RCLONE_SCRIPT by RUNCOMMAND-ONSTART
# RETURNS
#	0 > call found
#	1 > call created
function 3aRUNCOMMAND-ONSTART ()
{
	printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONSTART\tSTART\n" >> "${logfile}"
	
	# check if RUNCOMMAND-ONSTART.sh exists
	if [ -f /opt/retropie/configs/all/runcommand-onstart.sh ]
	then
		printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONSTART\tFILE FOUND\n" >> "${logfile}"
		
		# check if there's a call to RCLONE_SCRIPT
		if grep -Fq "~/scripts/rclone_script/rclone_script.sh" /opt/retropie/configs/all/runcommand-onstart.sh
		then
			printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONSTART\tCALL FOUND\n" >> "${logfile}"
			
			return 0
		else
			printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONSTART\tCALL NOT FOUND\n" >> "${logfile}"
			
			# add call
			printf "\n~/scripts/rclone_script/rclone_script.sh \"down\" \"\$1\" \"\$2\" \"\$3\" \"\$4\"\n" >> /opt/retropie/configs/all/runcommand-onstart.sh	

			printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONSTART\tCALL CREATED\n" >> "${logfile}"
			
			return 1
		fi
	else
		printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONSTART\tFILE NOT FOUND\n" >> "${logfile}"
	
		printf "#!/bin/bash\n~/scripts/rclone_script/rclone_script.sh \"down\" \"\$1\" \"\$2\" \"\$3\" \"\$4\"\n" > /opt/retropie/configs/all/runcommand-onstart.sh
		
		printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONSTART\tFILE CREATED\n" >> "${logfile}"
		
		return 1
	fi
}

# Checks call of RCLONE_SCRIPT by RUNCOMMAND-ONEND
# RETURNS
#	0 > call found
#	1 > call created
function 3aRUNCOMMAND-ONEND ()
{
	printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONEND\tSTART\n" >> "${logfile}"
	
	# check if RUNCOMMAND-ONEND.sh exists
	if [ -f /opt/retropie/configs/all/runcommand-onend.sh ]
	then
		printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONEND\tFILE FOUND\n" >> "${logfile}"
		
		# check if there's a call to RCLONE_SCRIPT
		if grep -Fq "~/scripts/rclone_script/rclone_script.sh" /opt/retropie/configs/all/runcommand-onend.sh
		then
			printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONEND\tCALL FOUND\n" >> "${logfile}"
			
			return 0
		else
			printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONEND\tCALL NOT FOUND\n" >> "${logfile}"
			
			# add call
			printf "\n~/scripts/rclone_script/rclone_script.sh \"up\" \"\$1\" \"\$2\" \"\$3\" \"\$4\"\n" >> /opt/retropie/configs/all/runcommand-onend.sh	

			printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONEND\tCALL CREATED\n" >> "${logfile}"
			
			return 1
		fi
	else
		printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONEND\tFILE NOT FOUND\n" >> "${logfile}"
	
		printf "#!/bin/bash\n~/scripts/rclone_script/rclone_script.sh \"up\" \"\$1\" \"\$2\" \"\$3\" \"\$4\"\n" >> /opt/retropie/configs/all/runcommand-onend.sh
		
		printf "$(date +%FT%T%:z):\t3aRUNCOMMAND-ONEND\tFILE CREATED\n" >> "${logfile}"
		
		return 1
	fi
}

function 4LocalSAVEFILEDirectory ()
{
# 4a. Test for local SAVEFILE directory
	updateStep "4a" "in progress" 70
	
	4aCheckLocalBaseDirectory
	case $? in
		0) updateStep "4a" "found" 75  ;;
		1) updateStep "4a" "created" 75  ;;
	esac

# 4b. Check local <SYSTEM> directories
	updateStep "4b" "in progress" 75
	
	4bCheckLocalSystemDirectories
	case $? in
		0) updateStep "4b" "found" 80  ;;
		1) updateStep "4b" "created" 80  ;;
	esac
}

# Checks if the local base SAVEFILE directory exists
# RETURN
#	0 > directory exists
#	1 > directory has been created
function 4aCheckLocalBaseDirectory ()
{
	printf "$(date +%FT%T%:z):\t4aCheckLocalBaseDirectory\tSTART\n" >> "${logfile}"
	
	# check if local base dir exists
	if [ -d ~/RetroPie/saves ]
	then
		printf "$(date +%FT%T%:z):\t4aCheckLocalBaseDirectory\tFOUND\n" >> "${logfile}"
		
		return 0
	else
		printf "$(date +%FT%T%:z):\t4aCheckLocalBaseDirectory\tNOT FOUND\n" >> "${logfile}"
		
		mkdir ~/RetroPie/saves
		printf "$(date +%FT%T%:z):\t4aCheckLocalBaseDirectory\tCREATED directory\n" >> "${logfile}"
		
		# share that new directory on the network
		if [[ $(grep -c "\[saves\]" /etc/samba/smb.conf) -eq 0 ]]
		then
			# add new share to SAMBA
			printf "[saves]\ncomment = saves\npath = \"/home/pi/RetroPie/saves\"\nwritable = yes\nguest ok = yes\ncreate mask = 0644\ndirectory mask = 0755\nforce user = pi\n" | sudo tee --append /etc/samba/smb.conf | cat > /dev/null
			
			# restart SAMBA
			sudo service smbd restart
			
			printf "$(date +%FT%T%:z):\t4aCheckLocalBaseDirectory\tCREATED network share\n" >> "${logfile}"
		fi
		
		return 1
	fi
}

# Checks if the local system specific directories exists
# RETURN
#	0 > all found
#	1 > created at least one
function 4bCheckLocalSystemDirectories ()
{
	printf "$(date +%FT%T%:z):\t4bCheckLocalSystemDirectories\tSTART\n" >> "${logfile}"
	local retval=0
	
	# for each directory in ROMS directory...
	for directory in ~/RetroPie/roms/*
	do
		system="${directory##*/}"
		
		# check if ROMS directory is a real directory and not a SymLink
		if [ ! -L ~/RetroPie/roms/${system} ]
		then
			# check if same directory exists in SAVES, create if necessary
			if [ -d ~/RetroPie/saves/${system} ] 
			then
				printf "$(date +%FT%T%:z):\t4bCheckLocalSystemDirectories\tFOUND directory ${system}\n" >> "${logfile}"
			else
				mkdir ~/RetroPie/saves/${system}
				printf "$(date +%FT%T%:z):\t4bCheckLocalSystemDirectories\tCREATED directory ${system}\n" >> "${logfile}"
				retval=1
			fi

			if [ "${system}" = "gc" ]
			then
			  if [ -d "/home/pi/.local/share/dolphin-emu/GC" ]
			  then
			    ln -s "/home/pi/.local/share/dolphin-emu/GC/USA" ~/RetroPie/saves/gc/USA
			    ln -s "/home/pi/.local/share/dolphin-emu/GC/EUR" ~/RetroPie/saves/gc/EUR
			    ln -s "/home/pi/.local/share/dolphin-emu/GC/JAP" ~/RetroPie/saves/gc/JAP
			  fi
			fi
		else
			# check if same SymLink exists in SAVES, create if necessary
			if [ -L ~/RetroPie/saves/${system} ]
			then
				printf "$(date +%FT%T%:z):\t4bCheckLocalSystemDirectories\tFOUND symlink ${system}\n" >> "${logfile}"
			else
				ln -s $(readlink ~/RetroPie/roms/${system}) ~/RetroPie/saves/${system}
				
				printf "$(date +%FT%T%:z):\t4bCheckLocalSystemDirectories\tCREATED symlink ${system}\n" >> "${logfile}"
				retval=1
			fi
		fi
	done
	
	return ${retval}
}

function 5RemoteSAVEFILEDirectory ()
{
# 5a. Check remote base directory
	updateStep "5a" "in progress" 80
	
	5aCheckRemoteBaseDirectory
	case $? in
		0) updateStep "5a" "found" 85  ;;
		1) updateStep "5a" "created" 85  ;;
		255) updateStep "5a" "failed" 80  ;;
	esac

# 5b. Check remote <system> directories
	updateStep "5b" "in progress" 85
	
	5bCheckRemoteSystemDirectories
	case $? in
		0) updateStep "5b" "found" 90  ;;
		1) updateStep "5b" "created" 90  ;;
		255) updateStep "5b" "failed" 85  ;;
	esac
}

# Checks if the remote base SAVEFILE directory exists
# RETURN
#	0 > directory exists
#	1 > directory has been created
#	255 > error while creating directory
function 5aCheckRemoteBaseDirectory ()
{
	printf "$(date +%FT%T%:z):\t5aCheckRemoteBaseDirectory\tSTART\n" >> "${logfile}"
	
	# try to read remote base dir
	rclone lsf "retropie:${remotebasedir}/" > /dev/null 2>&1
	case $? in
		0)
			printf "$(date +%FT%T%:z):\t5aCheckRemoteBaseDirectory\tFOUND\n" >> "${logfile}"
			return 0
			;;
		3)
			printf "$(date +%FT%T%:z):\t5aCheckRemoteBaseDirectory\tNOT FOUND\n" >> "${logfile}"
	
			rclone mkdir "retropie:${remotebasedir}" >> "${logfile}"
			case $? in
				0) 
					printf "$(date +%FT%T%:z):\t5aCheckRemoteBaseDirectory\tCREATED\n" >> "${logfile}"
					return 1 
					;;
				*) 
					printf "$(date +%FT%T%:z):\t5aCheckRemoteBaseDirectory\tERROR\n" >> "${logfile}"
					return 255
					;;
			esac
			;;
		*)
			printf "$(date +%FT%T%:z):\t5aCheckRemoteBaseDirectory\tERROR\n" >> "${logfile}"
			return 255
			;;
	esac
}

# Checks if the remote system specific directories exist
# RETURN
#	0 > all found
#	1 > created at least one
#	255 > error while creating directory
function 5bCheckRemoteSystemDirectories ()
{
	printf "$(date +%FT%T%:z):\t5bCheckRemoteSystemDirectories\tSTART\n" >> "${logfile}"
	
	local retval=0
	local output
	
	# list all directories in $REMOTEBASEDIR from remote
	remoteDirs=$(rclone lsf --dirs-only "retropie:${remotebasedir}/")
	
	# for each directory in ROMS directory...
	for directory in ~/RetroPie/roms/*
	do
		system="${directory##*/}"
		
		# use grep to search $SYSTEM in $DIRECTORIES
		output=$(grep "${system}/" -nx <<< "${remoteDirs}")
		
		if [ "${output}" = "" ]
		then
			# create system dir
			rclone mkdir retropie:"${remotebasedir}/${system}"
			
			if [[ $? -eq 0 ]]
			then
				printf "$(date +%FT%T%:z):\t5bCheckRemoteSystemDirectories\tCREATED ${system}\n" >> "${logfile}"
				
				# put note if local directory is a symlink
				if [ -L ~/RetroPie/saves/${system} ]
				then
					printf "ATTENTION\r\n\r\nThis directory will not be used! This is just a symlink.\r\nPlace your savefiles in\r\n\r\n$(readlink ~/RetroPie/roms/${system})\r\n\r\ninstead." > ~/scripts/rclone_script/readme.txt
					
					rclone copy ~/scripts/rclone_script/readme.txt retropie:"${remotebasedir}/${system}/"
					
					rm ~/scripts/rclone_script/readme.txt
				fi
				
				retval=1
			else
				printf "$(date +%FT%T%:z):\t5bCheckRemoteSystemDirectories\tERROR\n" >> "${logfile}"
				return 255
			fi
		else
			printf "$(date +%FT%T%:z):\t5bCheckRemoteSystemDirectories\tFOUND ${system}\n" >> "${logfile}"
		fi
	done
	
	return ${retval}
}

function 6ConfigureRETROARCH ()
{
# 6a. Setting local SAVEFILE directory
	updateStep "6a" "in progress" 90
	
	6aSetLocalSAVEFILEDirectory
	
	updateStep "6a" "done" 95
}

# Sets parameters in all system specific configuration files
function 6aSetLocalSAVEFILEDirectory ()
{
	printf "$(date +%FT%T%:z):\t6aSetLocalSAVEFILEDirectory\tSTART\n" >> "${logfile}"
	
	local retval
	
	# for each directory...
	for directory in /opt/retropie/configs/*
	do
		system="${directory##*/}"
		
		# skip directory ALL
		if [ "${system}" = "all" ]
		then
			continue
		fi
		
		# test if there's a RETROARCH.CFG
		if [ -f "${directory}/retroarch.cfg" ]
		then
			printf "$(date +%FT%T%:z):\t6aSetLocalSAVEFILEDirectory\tFOUND retroarch.cfg FOR ${system}\n" >> "${logfile}"
			
			# test file for SAVEFILE_DIRECTORY
			retval=$(grep -i "^savefile_directory = " ${directory}/retroarch.cfg)
		
			if [ ! "${retval}" = "" ]
			then
				printf "$(date +%FT%T%:z):\t6aSetLocalSAVEFILEDirectory\tREPLACED savefile_directory\n" >> "${logfile}"
			
				# replace existing parameter
				sed -i "/^savefile_directory = /c\savefile_directory = \"~/RetroPie/saves/${system}\"" ${directory}/retroarch.cfg
			else
				printf "$(date +%FT%T%:z):\t6aSetLocalSAVEFILEDirectory\tADDED savefile_directory\n" >> "${logfile}"
				
				# create new parameter above "#include..."
				sed -i "/^#include \"\/opt\/retropie\/configs\/all\/retroarch.cfg\"/c\savefile_directory = \"~\/RetroPie\/saves\/${system}\"\n#include \"\/opt\/retropie\/configs\/all\/retroarch.cfg\"" ${directory}/retroarch.cfg
			fi
			
			# test file for SAVESTATE_DIRECTORY
			retval=$(grep -i "^savestate_directory = " ${directory}/retroarch.cfg)
		
			if [ ! "${retval}" = "" ]
			then
				printf "$(date +%FT%T%:z):\t6aSetLocalSAVEFILEDirectory\tREPLACED savestate_directory\n" >> "${logfile}"
				
				# replace existing parameter
				sed -i "/^savestate_directory = /c\savestate_directory = \"~/RetroPie/saves/${system}\"" ${directory}/retroarch.cfg
			else
				printf "$(date +%FT%T%:z):\t6aSetLocalSAVEFILEDirectory\tADDED savestate_directory\n" >> "${logfile}"
			
				# create new parameter above "#include..."
				sed -i "/^#include \"\/opt\/retropie\/configs\/all\/retroarch.cfg\"/c\savestate_directory = \"~\/RetroPie\/saves\/${system}\"\n#include \"\/opt\/retropie\/configs\/all\/retroarch.cfg\"" ${directory}/retroarch.cfg
			fi
			
		fi
	done
	
	printf "$(date +%FT%T%:z):\t6aSetLocalSAVEFILEDirectory\tDONE\n" >> "${logfile}"
}

function 7Finalize ()
{
# 7a. Saving configuration
	updateStep "7a" "in progress" 95
	
	7aSaveConfiguration
	
	updateStep "7a" "done" 100
}

# Saves the configuration of RCLONE_SCRIPT
function 7aSaveConfiguration ()
{
	printf "$(date +%FT%T%:z):\t7aSaveConfiguration\tSTART\n" >> "${logfile}"
	
	echo "remotebasedir=${remotebasedir}" > ~/scripts/rclone_script/rclone_script.ini
	echo "showNotifications=${shownotifications}" >> ~/scripts/rclone_script/rclone_script.ini
	echo "syncOnStartStop=\"TRUE\"" >> ~/scripts/rclone_script/rclone_script.ini
	echo "logfile=~/scripts/rclone_script/rclone_script.log" >> ~/scripts/rclone_script/rclone_script.ini
	echo "neededConnection=${neededConnection}" >> ~/scripts/rclone_script/rclone_script.ini
	echo "debug=0" >> ~/scripts/rclone_script/rclone_script.ini
	
	printf "$(date +%FT%T%:z):\t7aSaveConfiguration\tDONE\n" >> "${logfile}"
}


########
# MAIN #
########

if [ "${branch}" == "beta" ]
then
	dialogBetaWarning
fi

installer
