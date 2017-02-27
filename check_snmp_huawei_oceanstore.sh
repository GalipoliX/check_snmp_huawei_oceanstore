#!/bin/bash
#################################################################################
# Script:       check_snmp_huawei_ocaeanstore
# Author:       Michael Geschwinder (Maerkischer-Kreis) 
# Description:  Plugin for Nagios to Monitor Huawei Oceanstore (tested with 5500 v3) 
#               storage units with snmp 
#
# Version:	1.0
# 
# History:                                                          
# 20170222      Created plugin
# 20170223      Added types: diskhealth, controllerhealth, powerhealth, fanhealth, bbuhealth, enclosurehealth
# 20170224      Added types: diskdomainhealth, stragepoolhealth & Added hadnling if there is no result from SNMP
# 20170224	Added types: sashealth, fchealth
# 20170227	Fixed enclosurehealth not detected as snmp table. Wuerying every column by hand.
#
#################################################################################################################
# Usage:        ./check_snmp_huawei_oceanstore.sh -H host -C community -t type [-w warning] [-c critical] [-D debug]
##################################################################################################################

help="check_snmp_huawei_oceanstore (c) 2017 Michael Geschwinder published under GPL license
\nUsage: ./check_snmp_huawei_oceanstore.sh -H host -C community -t type [-w warning] [-c critical] [-D debug]
\nRequirements: snmpget, awk, sed, grep\n
\nOptions: \t-H hostname\n\t\t-C Community (to be defined in snmp settings)\n\t\t-D enable Debug messages\n\t\t-t Type to check, see list below
\t\t-w Warning Threshold (optional)\n\t\t-c Critical Threshold (optional)\n
\nTypes:\t\t  
\t\tdiskhealth -> Checks the physical disks
\t\tcontrollerhealth -> Checks the controlle health
\t\tpowerhealth -> Checks the health of the powersupplys
\t\tfanhealth -> Checks the health of the fans
\t\tbbuhealth -> Checks the health of the Backup Battery Units
\t\tenclosurehealth -> Checks the health of the enclosures
\t\tdiskdomainhealth -> Checks the health of the diskdomain
\t\tstoragepoolhealth -> Checks the health of the storagepool
\t\tsashealth -> Checks the health of the SAS ports
\t\tfchealth -> Checks the health of the Fibre Channel ports" 
##########################################################
# Nagios exit codes and PATH
##########################################################
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown
PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/local/icinga/libexec: # Set path


##########################################################
# Debug Ausgabe aktivieren
##########################################################
DEBUG=0

##########################################################
# Debug output function
##########################################################
function debug_out {
	if [ $DEBUG -eq "1" ]
	then
		datestring=$(date +%d%m%Y-%H:%M:%S) 
		echo -e $datestring DEBUG: $1
	fi
}

###########################################################
# Check if programm exist $1
###########################################################
function check_prog {
	if ! `which $1 1>/dev/null`
	then
		echo "UNKNOWN: $1 does not exist, please check if command exists and PATH is correct"
		exit ${STATE_UNKNOWN}
	else
		debug_out "OK: $1 does exist"
	fi
}

############################################################
# Check Script parameters and set dummy values if required
############################################################
function check_param {
	if [ ! $host ]
	then
		echo "No Host specified... exiting..."
		exit $STATE_UNKNOWN
	fi

	if [ ! $community ]
	then
		debug_out "Setting default community (public)"
		community="public"
	fi
	if [ ! $type ]
	then
		echo "No check type specified... exiting..."
		exit $STATE_UNKNOWN
	fi
	if [ ! $warning ]
	then
		debug_out "Setting dummy warn value "
		warning=999
	fi
	if [ ! $critical ]
	then
		debug_out "Setting dummy critical value "
		critical=999
	fi
}



############################################################
# Get SNMP Value 
############################################################
function get_snmp {
	oid=$1
	snmpret=$(snmpget -v2c -c $community $host $oid) # | awk '{print $4}'
	echo "snmpget -v2c -c $community $host $oid"
	if [ $?  == 0 ]
	then
		echo $snmpret #| awk '{print $4}'
	else
		exit $STATE_UNKNOWN
	fi
}
############################################################
# Get SNMP Walk
############################################################
function get_snmp_walk {
	oid=$1
	snmpret=$(snmpwalk -v2c -c $community $host $oid -Oqv) # | awk '{print $4}'
	i=0
	IFS=$'\n'
	if [ $?  == 0 ]
	then
		for line in $snmpret 
		do
			line=$(echo $line | sed 's/\"/ /g')
			retval[$i]=$line
			let "i+=1"
		done;
	else
		exit $STATE_UNKNOWN
	fi
	IFS=$IFSold
	
}
############################################################
# Get SNMP Table
############################################################
function get_snmp_table {
	oid=$1
	snmpret=$(snmptable2csv $host --community=$community $oid)
	IFSold=$IFS
	IFS=$'\n'
	if [ $?  == 0 ]
	then
		for line in $snmpret 
		do
			echo $line
		done;
	else
		exit $STATE_UNKNOWN
	fi
	IFS=$IFSold
}


############################################################
# Huawei specific mappings 
############################################################

function get_healthstat {
	stat=$1

	case ${stat} in
	1)
		echo "Normal;$STATE_OK"
	;;
	2)
		echo "Fault;$STATE_CRITICAL"
	;;
	3)
		echo "Pre-fail;$STATE_CRITICAL"
	;;
	4)
		echo "Parity broken;$STATE_CRITICAL"
	;;
	5)
		echo "Degraded;$STATE_WARNING"
	;;
	6)
		echo "Bad sectors found;$STATE_CRITICAL"
	;;
	7)
		echo "Bit errors found;$STATE_CRITICAL"
	;;
	8)
		echo "Consistent;$STATE_OK"
	;;
	9)
		echo "Inconsistent;$STATE_CRITICAL"
	;;
	10)
		echo "Busy;$STATE_WARNING"
	;;
	11)
		echo "No input;$STATE_UNKNOWN"
	;;
	12)
		echo "Low Battery;$STATE_WARNING"
	;;
	13)
		echo "Single Link fault;$STATE_CRITICAL"
	;;
	14)
		echo "Invalid;$STATE_CRITICAL"
	;;
	15)
		echo "Write protect;$STATE_CRITICAL"
	;;
	*)
	esac
	
}

function get_runningstat {
stat=$1
case ${stat} in
1)
echo Normal
;;
2)
echo Running
;;
3)
echo Not running
;;
4)
echo Not existed
;;
5)
echo Sleep in high temperature
;;
6)
echo Starting
;;
7)
echo Power failure rotection
;;
8)
echo Spin down
;;
9)
echo Started
;;
10)
echo Link Up
;;
11)
echo Link Down
;;
12)
echo Powering on
;;
13)
echo Powered off
;;
14)
echo Pre-copy
;;
15)
echo Copyback
;;
16)
echo Reconstruction
;;
17)
echo Expansion
;;
18)
echo Unformatted
;;
19)
echo Formatting
;;
20)
echo Unmapped
;;
21)
echo Initial synchronizing
;;
22)
echo Consistent
;;
23)
echo Synchronizing
;;
24)
echo Synchronized
;;
25)
echo Unsynchronized
;;
26)
echo Split
;;
27)
echo Online
;;
28)
echo Offline
;;
29)
echo Locked
;;
30)
echo Enabled
;;
31)
echo Disabled
;;
32)
echo Balancing
;;
33)
echo To be recovered
;;
34)
echo Interrupted
;;
35)
echo Invalid
;;
36)
echo Not start
;;
37)
echo Queuing
;;
38)
echo Stopped
;;
39)
echo Copying
;;
40)
echo Completed
;;
41)
echo Paused
;;
42)
echo Reverse synchronizing
;;
43)
echo Activated
;;
44)
echo Restore
;;
45)
echo Inactive
;;
46)
echo Idle
;;
47)
echo Powering off
;;
48)
echo Charging
;;
49)
echo Charging completed
;;
50)
echo Discharging
;;
51)
echo Upgrading
;;
52)
echo Power Lost
;;
53)
echo Initializing
;;
54)
echo Apply change
;;
55)
echo Online disable
;;
56)
echo Offline disable
;;
57)
echo Online frozen
;;
58)
echo Offline frozen
;;
59)
echo Closed
;;
60)
echo Removing
;;
61)
echo In service
;;
62)
echo Out of service
;;
63)
echo Running normal
;;
64)
echo Running fail
;;
65)
echo Running success
;;
66)
echo Running success
;;
67)
echo Running failed
;;
68)
echo Waiting
;;
69)
echo Canceling
;;
70)
echo Canceled
;;
71)
echo About to synchronize
;;
72)
echo Synchronizing data
;;
73)
echo Failed to synchronize
;;
74)
echo Fault
;;
75)
echo Migrating
;;
76)
echo Migrated
;;
77)
echo Activating
;;
78)
echo Deactivating
;;
79)
echo Start failed
;;
80)
echo Stop failed
;;
81)
echo Decommissioning
;;
82)
echo Decommissioned
;;
83)
echo Recommissioning
;;
84)
echo Replacing node
;;
85)
echo Scheduling
;;
86)
echo Pausing
;;
87)
echo Suspending
;;
88)
echo Suspended
;;
89)
echo Overload
;;
90)
echo To be switch
;;
91)
echo Switching
;;
92)
echo To be cleanup
;;
93)
echo Forced start
;;
94)
echo Error
;;
95)
echo Job completed
;;
96)
echo Partition Migrating
;;
97)
echo Mount
;;
98)
echo Umount
;;
99)
echo INSTALLING
;;
100)
echo To Be Synchronized
;;
101)
echo Connecting
;;
102)
echo Service Switching
;;
103)
echo Power-on failed
;;
104)
echo REPAIRING
;;
105)
echo abnormal
;;
106)
echo Deleting
;;
107)
echo Modifying
;;
108)
echo "Running (clearing data)"
;;
109)
echo "Running(synchronizing data)"
;;
*)
echo UNKNOWN
esac
}


function get_disktype
{
dtype=$1
case ${dtype} in

	0)
		echo FC
	;;
	1)
		echo SAS
	;;
	2)
		echo SATA
	;;
	3)
		echo SSD
	;;
	4)
		echo NL_SAS
	;;
	5)
		echo SLC SSD
	;;
	6)
		echo MLC SSD
	;;
	7)
		echo FC_SED
	;;
	8)
		echo SAS_SED
	;;
	9)
		echo SATA_SED
	;;
	10)
		echo SSD_SED
	;;
	11)
		echo NL_SAS_SED
	;;
	12)
		echo SLC_SSD_SED
	;;
	13)
		echo MLC_SSD_SED
	;;

	*)
		echo UNKNOWN
	esac

}

function get_diskrole
{
	drole=$1
	case ${drole} in
	1)
		echo FREE
	;;
	2)
		echo MEMBER
	;;
	3)
		echo SPARE
	;;
	4)
		echo CACHE
	;;
	*)
		echo UNKNOWN
	esac
}

function get_controllerrole
{
	crole=$1
	case ${crole} in
	0)
		echo Normal
	;;
	1)
		echo Master
	;;
	2)
		echo Slave
	;;
	*)
		echo UNKNOWN
	esac
}

function get_enclogictype
{
        enctype=$1
        case ${enctype} in
        0)
                echo EXP
        ;;
        1)
                echo CTRL
        ;;
        2)
                echo DSW
        ;;
        3)
                echo MSW
        ;;
	4)
		echo SVP
	;;
        *)
                echo UNKNOWN
        esac
}

function get_enctype
{
        enctype=$1
        case ${enctype} in
        0)
                echo "BMC Controller"
        ;;
        1)
                echo "2U 2 Controllers and 12 Slot 3.5 SAS Disks Enclosure"
        ;;
        2)
                echo "2U 2 Controllers and 24 Slot 2.5 SAS Disks Enclosure"
        ;;
        16)
                echo "2U 12 Slot 3.5 SAS Disks Enclosure"
        ;;
	17)
		echo "2U 24 Slot 2.5 SAS Disks Enclosure"
	;;
	18)
		echo "4U 24 Slot 3.5 SAS Disks Enclosure"
	;;
	19)
		echo "4U 24 Slot 3.5 FC Disks Enclosure"
	;;
	20)
		echo "1U PCIE Switch Enclosure"
	;;
	21)
		echo "4U 75 Slot 3.5 SAS Disks Enclosure"
	;;
	22)
		echo "Service Processor Enclosure"
	;;
	23)
		echo "2U 2 Controllers and 12 Slot 3.5 SAS Disks Enclosure"
	;;
	24)
		echo "2U 25 Slot 2.5 SAS Disks Enclosure"
	;;
	25)
		echo "4U 24 Slot 3.5 SAS Disks Enclosure"
	;;
	26)
		echo "2U 2 Controllers and 25 Slot 2.5 SAS Disks Enclosure"
	;;
	37)
		echo "2U 2 Controllers and 12 Slot 3.5 SAS Disks Enclosure"
	;;
	38)
		echo "2U 2 Controllers and 25 Slot 2.5 SAS Disks Enclosure"
	;;
	96)
		echo "3U 2 Controllers Enclosure "
	;;
	97)
		echo "6U 4 Controllers Enclosure"
	;;
        *)
                echo UNKNOWN
        esac
}
function get_relocationstatus
{
	alocstat=$1
	case ${alocstat} in
	1)
		echo Ready
	;;
	2)
		echo Migrating
	;;
	3)
		echo Paused
	;;
	*)
		echo UNKNOWN
	esac
}
function get_portrole
{
	srole=$1
	case ${srole} in
	2)
		echo INI
	;;
	3)
		echo TGT
	;;
	4)
		echo INI_AND_TGT
	;;
	4294967295)
		echo Invalid
	;;
	*)
		echo UNKNOWN
	esac
}
function get_portlogictype
{
	plogtype=$1
	case ${plogtype} in
	0)
		echo HOST
	;;
	1)
		echo EXP
	;;
	2)
		echo MNGT
	;;
	3)
		echo INNER
	;;
	4)
		echo MAINTENANCE
	;;
	5)
		echo MNGT_SRV
	;;
	6)
		echo MAINTENANCE_SRV
	;;
	7)
		echo BACKUP_MGR
	;;
	8)
		echo PRODUCT_STORAGE
	;;
	9)
		echo BACKUP_STORAGE
	;;
	10)
		echo ETH_NOT_CONFIG
	;;
	11)
		echo IP_SCALE_OUT
	;;
	*)
		echo UNKNOWN
	esac
}

function get_sfpstatus
{
	val=$1
	case ${val} in
	0)
		echo Not Exist
	;;
	1)
		echo Offline
	;;
	2)
		echo Online
	;;
	4294967295)
		echo Invalid
	;;
	*)
		echo UNKNOWN
	esac
}

function get_fcmode
{
	val=$1
	case ${val} in
	0)
		echo Fabric
	;;
	1)
		echo FC-ALe
	;;
	2)
		echo Point to Point
	;;
	3)
		echo Auto
	;;
	4294967295)
		echo Invalid
	;;
	*)
		echo UNKNOWN
	esac
}

function get_noyes
{
	val=$1
	case ${val} in
	0)
		echo No
	;;
	1)
		echo Yes
	;;
	*)
		echo UNKNOWN
	esac
	
	
}
function check_ret
{
	if [ "$1" == "" ]
	then
		echo "No data received!"
		exit $STATE_UNKNOWN
	fi
}

#################################################################################
# Display Help screen
#################################################################################
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit $STATE_UNKNOWN;
fi

################################################################################
# check if requiered programs are installed
################################################################################
for cmd in snmpget snmpwalk snmptable2csv awk sed grep;do check_prog ${cmd};done;

################################################################################
# Get user-given variables
################################################################################
while getopts "H:C:t:w:c:o:D" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       C)      community=${OPTARG};;
       t)      type=${OPTARG};;
       w)      warning=${OPTARG};;
       c)      critical=${OPTARG};;
       o)      moid=${OPTARG};;
       D)      DEBUG=1;;
       *)      echo "Wrong option given. Please use options -H for host, -c for SNMP-Community, -t for type, -w for warning and -c for critical"
               exit 1
               ;;
       esac
done

debug_out "Host=$host, Community=$community, Type=$type, Warning=$warning, Critical=$critical"

check_param



#################################################################################
# Switch Case for different check types
#################################################################################
case ${type} in
#manual oid
manual)
	declare -A retval
	set -e
	get_snmp_walk $moid
	a=("${retval[@]}") 
	echo "length:"
	echo ${#a[@]}
	echo ${a[@]}
	set +e
	exit
;;

diskhealth)
	set -e
	#echo -e "id\thealthstat\trunningstat\tlocation\ttype\tcapacity\tdiskrole\tdiskspeed\ttemp\tmodel\t\t\tfwversion=\tmanufacturer\t\tserial\t\tdomain\truntime"
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.1.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	messagetext="disks "
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')

		id=$(echo $line | cut -d "," -f1)
		healthstat=$(echo $line | cut -d "," -f2)
		runningstat=$(echo $line | cut -d "," -f3)
		location=$(echo $line | cut -d "," -f4)
		type=$(echo $line | cut -d "," -f5)
		capacity=$(echo $line | cut -d "," -f6)
		diskrole=$(echo $line | cut -d "," -f7)
		diskspeed=$(echo $line | cut -d "," -f8)
		temp=$(echo $line | cut -d "," -f11)
		model=$(echo $line | cut -d "," -f12)
		fwversion=$(echo $line | cut -d "," -f13)
		manufacturer=$(echo $line | cut -d "," -f14)
		serial=$(echo $line | cut -d "," -f15)
		domain=$(echo $line | cut -d "," -f18)
		runtime=$(echo $line | cut -d "," -f21)

		healthstatret=$(get_healthstat $healthstat)
		nagret=$(echo $healthstatret | cut -d ";" -f2)
		healthstat=$(echo $healthstatret | cut -d ";" -f1)
		runningstat=$(get_runningstat $runningstat)
		type=$(get_disktype $type)
		capacity=$(echo "scale=0 ;  $capacity / 1024" | bc -l)	
		capacity=$(echo "${capacity}GB")
		diskrole=$(get_diskrole $diskrole)

		outtext="id=$id\thealthstatus=$healthstat\trunningstatus=$runningstat\tlocation=$location\ttype=$type\tcapacity=$capacity\trole=$diskrole\tspeed=$diskspeed rpm\t\ttemp=$temp\tmodel=$model\t\tfwversion=$fwversion\tmanufacturer=$manufacturer\tserial=$serial\tdomain=$domain\truntime=$runtime days\n"
	
		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi
		
		
	done;
	IFS=$IFSold
	set +e
;;


controllerhealth)
	messagetext="Controllers"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.2.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')

		id=$(echo $line | cut -d "," -f1)
		healthstat=$(echo $line | cut -d "," -f2)
		runningstat=$(echo $line | cut -d "," -f3)
		cpu=$(echo $line | cut -d "," -f4)
		location=$(echo $line | cut -d "," -f5)
		role=$(echo $line | cut -d "," -f6)
		cachecapacity=$(echo $line | cut -d "," -f7)
		cpuusage=$(echo $line | cut -d "," -f8)
		memusage=$(echo $line | cut -d "," -f9)
		voltage=$(echo $line | cut -d "," -f10)
		swversion=$(echo $line | cut -d "," -f11)
		pcbversion=$(echo $line | cut -d "," -f12)
		sesversion=$(echo $line | cut -d "," -f13)
		bmcversion=$(echo $line | cut -d "," -f14)
		logicversion=$(echo $line | cut -d "," -f15)
		biosversion=$(echo $line | cut -d "," -f16)
		elabel=$(echo $line | cut -d "," -f17)
	
		#echo -e "id=$id\thealthstat=$healthstat\trunningstat=$runningstat\tcpu=$cpu\tlocation=$location\trole=$role\tcachecapacity=$cachecapacity\tcpuusage=$cpuusage\tmemusage=$memusage\tvoltage=$voltage\t
		#	swversion=$swversion\tpcbversion=$pcbversion\tsesversion=$sesversion\tbmcversion=$bmcversion\tlogicversion=$logicversion\tbiosversion=$biosversion\t"

		#echo $elabel
			
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)

		role=$(get_controllerrole $role)
		voltage=$(echo "scale=0 ;  $voltage * 0.1 " | bc -l)$(echo V) 

		outtext="id=$id\thealthstat=$healthstat\trunningstat=$runningstat\tcpu=$cpu\tlocation=$location\trole=$role\tcachecapacity=$cachecapacity\tcpuusage=$cpuusage\tmemusage=$memusage\tvoltage=$voltage\tswversion=$swversion\tpcbversion=$pcbversion\tsesversion=$sesversion\tbmcversion=$bmcversion\tlogicversion=$logicversion\tbiosversion=$biosversion\n"

		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

	
		
	done;
	IFS=$IFSold
	set +e
;;

powerhealth)
	messagetext="Powersupplys"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.3.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')
		location=$(echo $line | cut -d "," -f2)
		healthstat=$(echo $line | cut -d "," -f3)
		runningstat=$(echo $line | cut -d "," -f4)
		powertype=$(echo $line | cut -d "," -f5)
		manufacturer=$(echo $line | cut -d "," -f6)
		model=$(echo $line | cut -d "," -f7)
		version=$(echo $line | cut -d "," -f8)
		produced=$(echo $line | cut -d "," -f9)
		serial=$(echo $line | cut -d "," -f10)


		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)

		outtext="location=$location\thealth=$healthstat\trunningstat=$runningstat\tpowertype=$powertype\tmanufracturer=$manufacturer\tmodel=$model\tversion=$version\tproduced=$produced\tserial=$serial\n"		

		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

		
		
		
	done;
	IFS=$IFSold
	set +e
;;

fanhealth)
	messagetext="fans"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.4.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')
		location=$(echo $line | cut -d "," -f2)
		healthstat=$(echo $line | cut -d "," -f3)
		runningstat=$(echo $line | cut -d "," -f4)
		level=$(echo $line | cut -d "," -f5)
		elabel=$(echo $line | cut -d "," -f6)
	
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)

		#echo $elabel
		
		outtext="location=$location\thealth=$healthstat\trunningstat=$runningstat\tlevel=$level\n"
		
		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

	done;
	IFS=$IFSold
	set +e
;;

bbuhealth)
	messagetext="BBUs"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.5.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')
		location=$(echo $line | cut -d "," -f2)
		healthstat=$(echo $line | cut -d "," -f3)
		runningstat=$(echo $line | cut -d "," -f4)
		type=$(echo $line | cut -d "," -f5)
		curvoltage=$(echo $line | cut -d "," -f6)
		discharges=$(echo $line | cut -d "," -f7)
		fwversion=$(echo $line | cut -d "," -f8)
		deliveredon=$(echo $line | cut -d "," -f9)
		owningcontroller=$(echo $line | cut -d "," -f10)
		elabel=$(echo $line | cut -d "," -f11)
		
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)
	
		#echo $elabel
		outtext="location=$location\thealth=$healthstat\trunningstat=$runningstat\ttype=$type\tcurvoltage=$curvoltage\tdischarges=$discharges\tfwversion=$fwversion\tdeliveredon=$deliveredon\towningcontroller=$owningcontroller\n"
		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

	done;
	IFS=$IFSold
	set +e
;;		
		
enclosurehealth)
	messagetext="Enclosures"
	count=0

	declare -A retval
	
	set -e
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.1
	a=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.2
	b=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.3
	c=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.4
	d=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.5
	e=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.6
	f=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.7
	g=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.8
	h=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.9
	i=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.10
	j=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.11
	k=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.12
	l=("${retval[@]}") 
	retval=()
	get_snmp_walk .1.3.6.1.4.1.34774.4.1.23.5.6.1.13
	m=("${retval[@]}") 
	retval=()
	set +e
	
	for i in "${a[@]}"
	do
		ret=$(echo -e "${ret}\n${i},${b[$count]},${c[$count]},${d[$count]},${e[$count]},${f[$count]},${g[$count]},${h[$count]},${i[$count]},${j[$count]},${k[$count]},${l[$count]}")
		let "count+=1"
	   : 
	   # do whatever on $i
	done	
	


	#ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.6.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')

		name=$(echo $line | cut -d "," -f2)
		logictype=$(echo $line | cut -d "," -f3)
		healthstat=$(echo $line | cut -d "," -f4)
		runningstat=$(echo $line | cut -d "," -f5)
		location=$(echo $line | cut -d "," -f6)
		type=$(echo $line | cut -d "," -f7)
		temp=$(echo $line | cut -d "," -f8)
		sn=$(echo $line | cut -d "," -f9)
		mac=$(echo $line | cut -d "," -f10)
		elabel=$(echo $line | cut -d "," -f13)
		
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)
		
		logictype=$(get_enclogictype $logictype)
		type=$(get_enctype $type)
		temp=$(echo "${temp}C°")
	
		#echo $elabel
		outtext="name=$name\tlogictype=$logictype\thealth=$healthstat\trunningstat=$runningstat\tlocation=$location\ttype=$type\ttemp=$temp\tsn=$sn\tmac=${mac}\n"
		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext") 
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

	done;
	IFS=$IFSold
;;		
diskdomainhealth)
	messagetext="diskdomains"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.4.1.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')
		
		name=$(echo $line | cut -d "," -f2)
		healthstat=$(echo $line | cut -d "," -f3)
		runningstat=$(echo $line | cut -d "," -f4)
		totalcapacity=$(echo $line | cut -d "," -f5)
		freecapacity=$(echo $line | cut -d "," -f6)
		hotsparecapacity=$(echo $line | cut -d "," -f7)
	
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)
		
		outtext="name=$name\thealth=$healthstat\trunningstat=$runningstat\ttotalcapacity=$totalcapacity\tfreecapacity=$freecapacity\thotsparecapacity=$hotsparecapacity\n"

		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi

	done;
	IFS=$IFSold
	set +e
;;

storagepoolhealth)
	messagetext="storagepools"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.4.2.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')

		poolname=$(echo $line | cut -d "," -f2)
		diskdomainid=$(echo $line | cut -d "," -f3)
		diskdomainname=$(echo $line | cut -d "," -f4)
		healthstat=$(echo $line | cut -d "," -f5)
		runningstat=$(echo $line | cut -d "," -f6)
		totalcapacity=$(echo $line | cut -d "," -f7)
		protectioncapacity=$(echo $line | cut -d "," -f8)
		freecapacity=$(echo $line | cut -d "," -f9)
		relocationstatus=$(echo $line | cut -d "," -f17)
		
	
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)
		relocationstatus=$(get_relocationstatus $relocationstatus)


		
		outtext="poolname=$poolname\tdiskdomainid=$diskdomainid\tdiskdomainname=$diskdomainname\thealthstat=$healthstat\trunningstat=$runningstat\ttotalcapacity=$totalcapacity\tprotectioncapacity=$protectioncapacity\tfreecapacity=$freecapacity\trelocationstatus=$relocationstatus\n"
	
		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi
	done;
	IFS=$IFSold
	set +e
;;
fchealth)
	messagetext="Fibre Channel ports"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.9.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')

		location=$(echo $line | cut -d "," -f2)
		healthstat=$(echo $line | cut -d "," -f3)
		runningstat=$(echo $line | cut -d "," -f4)
		type=$(echo $line | cut -d "," -f5)
		workingrate=$(echo $line | cut -d "," -f6)
		speed=$(echo $line | cut -d "," -f7)
		wwn=$(echo $line | cut -d "," -f8)
		role=$(echo $line | cut -d "," -f9)
		sfpstatus=$(echo $line | cut -d "," -f10)
		workingmode=$(echo $line | cut -d "," -f11)
		configuredmode=$(echo $line | cut -d "," -f12)
		lostsignals=$(echo $line | cut -d "," -f14)
		linkerrors=$(echo $line | cut -d "," -f15)
		lostsync=$(echo $line | cut -d "," -f16)
		failedconnects=$(echo $line | cut -d "," -f17)
	
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)
		
		type=$(get_portlogictype $type)
		role=$(get_portrole $role)
		sfpstatus=$(get_sfpstatus $sfpstatus)
		workingmode=$(get_fcmode $workingmode)
		configuredmode=$(get_fcmode $configuredmode)

		
		outtext="location=$location\thealthstat=$healthstat\trunningstat=$runningstat\tporttype=$type\tworkingrate=$workingrate\tspeed=$speed\twwn=$wwn\trole=$role\tsfpstatus=$sfpstatus\tworkingmode=$workingmode\tconfiguredmode=$configuredmode\tlostsignals=$lostsignals\tlinkerrors=$linkerrors\tlostsyncs=$lostsync\tfailedconnects=$failedconnects\n"
	
		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi
	done;
	IFS=$IFSold
	set +e
;;
sashealth)
	messagetext="SAS ports"
	set -e
	ret=$(get_snmp_table .1.3.6.1.4.1.34774.4.1.23.5.12.1)
	check_ret $ret
	IFSold=$IFS
	IFS=$'\n'
	for line in $ret
	do
		line=$(echo $line | sed 's/\"//g')

		location=$(echo $line | cut -d "," -f2)
		healthstat=$(echo $line | cut -d "," -f3)
		runningstat=$(echo $line | cut -d "," -f4)
		type=$(echo $line | cut -d "," -f5)
		workingrate=$(echo $line | cut -d "," -f6)
		wwn=$(echo $line | cut -d "," -f7)
		role=$(echo $line | cut -d "," -f8)
		invaliddwords=$(echo $line | cut -d "," -f9)
		consisterrors=$(echo $line | cut -d "," -f10)
		lossdwords=$(echo $line | cut -d "," -f11)
		physresets=$(echo $line | cut -d "," -f12)
		starttime=$(echo $line | cut -d "," -f13)
		enabled=$(echo $line | cut -d "," -f14)
	
		healthstatret=$(get_healthstat $healthstat)
                nagret=$(echo $healthstatret | cut -d ";" -f2)
                healthstat=$(echo $healthstatret | cut -d ";" -f1)
                runningstat=$(get_runningstat $runningstat)
		
		type=$(get_portlogictype $type)
		role=$(get_portrole $role)
		enabled=$(get_noyes $enabled)

		
		outtext="location=$location\thealthstat=$healthstat\trunningstat=$runningstat\tporttype=$type\tworkingrate=$workingrate\twwn=$wwn\trole=$role\tinvaliddword=$invaliddwords\tconsistencyerrors=$consisterrors\tlostdwords=$lossdwords\tphysicalresets=$physresets\tstarttime=$starttime\tenabled=$enabled\n"
	
		if [ "$nagret" == "$STATE_CRITICAL" ]
                then
                        crittext=$(echo "$crittext $outtext")
                        CRIT=true
                elif [ "$nagret" == "$STATE_WARNING" ]
                then
                        warntext=$(echo "$warntext $outtext")
                        WARN=true
                elif [ "$nagret" == "$SATE_UNKNOWN" ]
                then
                        unknowntext=$(echo "$unknowntext $outtext")
                        UNKNOWN=true
                else
                        oktext=$(echo "$oktext $outtext")
                fi
	done;
	IFS=$IFSold
	set +e
;;
*)
	echo -e "${help}";
	exit $STATE_UNKNOWN;

esac








###################################################################################################################################
# Output an exit status
###################################################################################################################################

if [ $CRIT ]
then
	echo "One or more $messagetext are in critical state!"
	echo -e "CRITICAL: \n$crittext"
	echo -e "\nWARNING: \n$warntext"
	echo -e "\nOK: \n$oktext"
	echo -e "\nUNKNOWN: \n$unknowntext"
	exit $STATE_CRITICAL
elif [ $WARN ]
then
	echo "One or more $messagetext are in warning state!"
        echo -e "\nWARNING: \n$warntext"
        echo -e "\nOK: \n$oktext"
        echo -e "\nUNKNOWN: \n$unknowntext"
	exit $STATE_WARNING
elif [ $UNKNOWN ]
then
	echo "One or more $messagetext are in unknown state!"
        echo -e "\nUNKNOWN: \n$unknowntext"
        echo -e "\nOK: \n$oktext"
	exit $STATE_UNKNOWN
else
	echo "All $messagetext are in OK state!"
        echo -e "\nOK: \n$oktext"
	exit $STATE_OK
fi
