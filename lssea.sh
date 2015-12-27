#!/bin/ksh

if tty -s
then
esc=`printf "\033"`
extd="${esc}[1m"
r="${esc}[1;31m"
g="${esc}[1;32m"
y="${esc}[1;33m"
n=`printf "${esc}[m\017"`
green="${esc}[1;32m"
yellow="${esc}[1;33m"
blue="${esc}[1;34m"
magenta="${esc}[1;35m"
cyan="${esc}[1;36m"
norm=`printf "${esc}[m\017"`
fi


SEA=$1
SN=$(prtconf | awk -F: '/Serial Number/{print $2}')


GetMacOfEntInit=0
###=============================================================================
function GetMacOfEnt
###=============================================================================
{
if [ "x$GetMacOfEntInit" = "x0" ]; then
  GetMacOfEntInit=1
   lscfg -l ent* | grep Port | while  read ent pl x
   do
     echo "$ent $pl $(lscfg  -l $ent -v|awk -F'.' '/Network Address/{print $NF}')" >/tmp/$ent.plmac
   done
fi
ENT=$1
if [ -r /tmp/$ENT.plmac ]; then
  MAC=$(awk '{print $NF}' < /tmp/$ENT.plmac)
  echo $MAC
fi
}
###=============================================================================
function EntOfEn
###=============================================================================
{
  echo $1 | sed -e 's/\(en\)\([0-9]\)/ent\2/g'
} ###===========================================================================

###=============================================================================
function EnOfEnt
###=============================================================================
{
  echo $1 | sed -e 's/ent/en/g'
} ###===========================================================================

###=============================================================================
function attr
###=============================================================================
{
aDEV=$1
aATTR=$2

if [ -n "$aDEV" ]; then
  if [ -n "$aATTR" ]; then
    lsattr -El $aDEV |
      awk '/^'${aATTR}' /{print $2}'
  fi
fi
} ###===========================================================================

###=============================================================================
function shortmask
###=============================================================================
{
  longmask=$1
  case $longmask in
    255.255.224.0)   shortmask=20;;
    255.255.240.0)   shortmask=21;;
    255.255.248.0)   shortmask=22;;
    255.255.252.0)   shortmask=23;;
    255.255.255.0)   shortmask=24;;
    255.255.255.128) shortmask=25;;
    255.255.255.192) shortmask=26;;
    255.255.255.224) shortmask=27;;
    255.255.255.240) shortmask=28;;
    255.255.255.248) shortmask=29;;
    255.255.255.252) shortmask=30;;
  esac
  echo $shortmask
} ###===========================================================================

###=============================================================================
function oneline
###=============================================================================
{
a="";while read L
do
a="$a $L"
done
echo $a
} ###===========================================================================

function colstate
{
  case $1 in
    en*)  thisEN=$(echo $1| sed -e 's/ent/en/g')
          thisState=$(attr $thisEN state)
          case $thisState in
            down) echo "$r$thisState$n";;
            up)   echo "$g$thisState$n";;
            *)    echo "$y$thisState$n";;
          esac;;
  esac          
} ###===========================================================================

###=============================================================================
function getmac
###=============================================================================
{
  if [ -n "$1" ]; then
    thisENT=$(EntOfEn $1)
    PACKED=$(lscfg -l $thisENT -v 2>/dev/null|grep "Network Address" | awk -F"." '{print $NF}')
    echo "$(echo $PACKED|cut -c1-2):$(echo $PACKED|cut -c3-4):$(echo $PACKED|cut -c5-6):$(echo $PACKED|cut -c7-8):$(echo $PACKED|cut -c9-10):$(echo $PACKED|cut -c11-12)"
  fi
} ###===========================================================================

###=============================================================================
function ls_if
###=============================================================================
{
  printf "IP Interfaces:\n"
  for ipent in $(ifconfig -a |
    egrep "^en[0-9]*:" |
    cut -d: -f1)
  do
    ipen=$(EnOfEnt $ipent)
    ip=$(attr $ipen netaddr)
    ipstate=$(colstate $ipen)
    Lmask=$(attr $ipen netmask)
    Smask=$(shortmask $Lmask)
    baseadapter=$(attr $ipent base_adapter)
    printf "$y$ipent$n: $g$ip$n/$y$Smask$n $ipstate "
    if [ -n "$baseadapter" ]; then
      printf "LinkAggr: $y$baseadapter$n NICs: \n"
      physniclist=$(attr $baseadapter adapter_names | sed -e 's/,/ /g')
      for aPhysNIC in $physniclist
      do
        en=$(EnOfEnt $aPhysNIC)
        state=$(attr $en state)
        aMAC=$(getmac $aPhysNIC)
        DEV=$(lscfg -l $aPhysNIC| awk '{print $2}')
        case $state in
          down) state="$r$state$n";;
          *)    state="$g$state$n";;
        esac
        printf "  $y$aPhysNIC$n ($y$DEV$n,$y$aMAC$n) ($state) \n"
      done
    fi
    printf "\n"
  done
} ###===========================================================================


###=============================================================================
function ls_sea
###=============================================================================
{

sea=$1


/usr/ios/cli/ioscli lsdev -dev $sea -attr > /tmp/$sea.lsattr
CTLCHAN=$(awk '/^ctl_chan/{print $2}' /tmp/$sea.lsattr)
PVID_ENT=$(awk '/^pvid_adapter/{print $2}' /tmp/$sea.lsattr)
REAL_NIC=$(awk '/^real_adapter/{print $2}' /tmp/$sea.lsattr)

lsattr -El $sea > /tmp/$sea.lsattr
HAMODE=$(awk '/^ha_mode/{print $2}' /tmp/$sea.lsattr)


lsattr -El ${REAL_NIC} > /tmp/${REAL_NIC}.lsattr
NICS=$(awk '/^adapter_names/{print $2}' /tmp/${REAL_NIC}.lsattr| sed -e 's/,/ /g')
MODE=$(awk '/^mode/{print $2}' /tmp/${REAL_NIC}.lsattr)
INTERVAL=$(awk '/^interval/{print $2}' /tmp/${REAL_NIC}.lsattr)

echo "  BACK: $g${REAL_NIC}$n $cyan$(getmac ${REAL_NIC})$n"
if [ -n "$NICS" ]; then
  for nic in $NICS
  do
    DEV=$(lscfg -l $nic | awk '{print $2}')
    echo "  NIC:  $g$nic$n $y$DEV$n $cyan"$(getmac $nic)"$n"
  done
fi

ADD=""
if [ -n "$MODE" ]; then
  ADD="$ADD MODE: $y$MODE$n"
fi
#if [ -n "$INTERVAL" ]; then
#  ADD="$ADD INTERVAL: $INTERVAL"
#fi
#if [ -n "$CTLCHAN" ]; then
#  ADD="$ADD ControlChannel: $y$CTLCHAN$n"
#fi
if [ -n "$ADD" ]; then
  echo " $ADD"
fi


if  entstat -d $sea > /tmp/1 2>/dev/null
then
  awk 'BEGIN{addvlan=0}
 function prha(thishamode) {
 if(thishamode ~ /standby/){print "    HA: " r hamode n;}
 if(thishamode ~ /auto/)   {print "    HA: " g hamode n;}
 }
 function slot(aENT) {
   aCMD="lscfg -l " aENT " | cut -d\"-\" -f3"
   aCMD | getline aCSLOT
   return sprintf ("%-2d" ,substr(aCSLOT,2))
 }
 function Partner () {
 if(ShowPartner > 0){return " with Switch: " y SwitchMac n " / " m SwitchPort n ;}
 else{return "";}
 }
# /Real Adapter:/{print "  BACK: " g $NF n}
 /Virtual Adapter:/              {V="  SVEA: " g $NF n " Slot: " m slot($NF) n " "}
 /Control Channel Adapter:/      {V="  CtlC: " y $NF n }
 /Active:/                       {V=V" Active:"g $4 n }
 /Port VLAN ID:/                 {PVID=$NF}
 /Partner System Priority:/      {ShowPartner=1;SwitchMac="";SwitchPort="";}
 /Expired/                       {ShowPartner=0;}
 /State: PRIMARY/                {prha(hamode);print "  STAT: " g $2 n}
 /State: BACKUP/                 {prha(hamode);print "  STAT: " r $2 n}
 /Control Channel PVID:/         {PVID=$NF}
 /Link Status : Up/              {LINK=$NF; print "  LINK: " g LINK n}
 /Link Status : Down/            {LINK=$NF; print "  LINK: " r LINK n}
 /Physical Port Link State: Up/  {LINK=$NF; print "  LINK: " g LINK n}
 /Physical Port Link State: Down/{LINK=$NF; print "  LINK: " r LINK n}
 /Partner System:/               {SwitchMac=$NF}
 /Partner Port:/                 {SwitchPort=$NF}
 /Synchronization: IN_SYNC/      {SYNC=$NF; print "  Sync: " g SYNC n Partner()}
 /Synchronization: OUT_OF_SYNC/  {SYNC=$NF; print "  Sync: " r SYNC n Partner()}
 /Switch ID:/                    {addvlan=0}
                                 {if(addvlan>0){for (i = 1; i <= NF; i++){vlans=vlans " " $i}}}
 /VLAN Tag IDs:/                 {split($0,a,":");vlans=a[2];addvlan=1}
 /Switch ID:/                    {addvlan=0;print V " PVID:" y PVID n " VLANs:" g vlans n;
                                  V="";PVID=""}
' y=$y n=$n g=$g r=$r m=$magenta hamode=$HAMODE /tmp/1
fi
} ###===========================================================================



################################################################################
### MAIN ###
################################################################################
echo "  ### $version on MS: $y$SN$n host: $y$(hostname)$n $*"
if [ -n "$SEA" ]; then
  printf "SEA: ===>>>   $g$SEA$n  \n"
  ls_sea $SEA
else
  lsdev -Cc adapter | grep "Shared Ethernet" | while read SEA b c
  do
    printf "SEA: ===>>>   $g$SEA$n  \n"
    ls_sea $SEA
  done
  echo "Listing active IP Interfaces ..."
  #for en in $(ifconfig -a | awk -F: '/^en/{print $1}')
  #To avoid interface with "*" from netstat -ni, eg. "en9*" - Merci, Bruno
  for en in $(netstat -ni | awk '{ print $1 }' | egrep -v "^Name|^lo0|\*$"|uniq)
   do
     VLAN=$( entstat -d $en | awk '/^Port VLAN ID:/{print $4}')
     ent=ent${en#en}
     SLOT=$( lscfg -l $ent|cut -d"-" -f3|cut -c2-)
     ifconfig $en | awk '/inet/{
      printf "  %s: Slot: %s%.2d%s %s%s%s/%s%d.%d.%d.%d%s PVID: %s%s%s MAC:%s%s%s\n",
       en, m, sl, n, g, $2 , n , y,
       "0x" substr($4,3,2),
       "0x" substr($4,5,2),
       "0x" substr($4,7,2),
       "0x" substr($4,9,2), n,
       g, vlan, n, c, mac, n
      }' en=$en sl=$SLOT r=$r g=$g y=$y n=$n c=$cyan m=$magenta vlan=$VLAN mac=$(getmac $ent)
   done

fi
