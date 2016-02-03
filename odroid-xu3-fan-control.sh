#!/bin/bash

# Make sure only root can run our script
if (( $EUID != 0 )); then
   echo "This script must be run as root:" 1>&2
   echo "sudo $0" 1>&2
   exit 1
fi

if [ -f /sys/devices/odroid_fan.13/fan_mode ]; then
   FAN=13
elif [ -f /sys/devices/odroid_fan.14/fan_mode ]; then
   FAN=14
else
   echo "This machine is not supported."
   exit 1
fi

TEMPERATURE_FILE="/sys/devices/10060000.tmu/temp"
FAN_MODE_FILE="/sys/devices/odroid_fan.$FAN/fan_mode"
FAN_SPEED_FILE="/sys/devices/odroid_fan.$FAN/pwm_duty"
TEMP_STEPS=(2  50000  55000  60000  65000  70000  75000  80000)
FAN_STEPS=(2  64     96     128    160    192    224    255)

#make sure after quiting script fan goes to auto control
function cleanup {
  echo " event: quit; temp: auto"
  echo 1 > ${FAN_MODE_FILE}
}
trap cleanup EXIT

function exit_xu3_only_supported {
  echo "event: non-xu3 $1"
  exit 2
}

function write_status {
  echo -ne "\r[Status] Temp: $(($1/1000))C, Fan Speed: $(($2*100/255))%"
  printf "%0.s " {1..10}
}

function get_speed {
  # loop through temps
  for x in 7 6 5 4 3 2 1 0
  do
    if (( $1 >= ${TEMP_STEPS[${x}]} )); then
      return x
    fi
  done
  return 1
}

if [ ! -f $TEMPERATURE_FILE ]; then
  exit_xu3_only_supported "no temp file"
elif [ ! -f $FAN_MODE_FILE ]; then
  exit_xu3_only_supported "no fan mode file"
elif [ ! -f $FAN_SPEED_FILE ]; then
  exit_xu3_only_supported "no fan speed file"
fi


current_max_temp=`cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1`
echo "Fan control started. Current cpu temp: ${current_max_temp}"

echo 0 > ${FAN_MODE_FILE} #to be sure we can manage fan
prev_step=0

while [ true ];
do

  current_max_temp=`cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1`

  new_fan_speed=0
  if (( ${current_max_temp} >= 75000 )); then
    new_fan_speed=255
  elif (( ${current_max_temp} >= 70000 )); then
    new_fan_speed=200
  elif (( ${current_max_temp} >= 68000 )); then
    new_fan_speed=160
  elif (( ${current_max_temp} >= 66000 )); then
    new_fan_speed=120
  elif (( ${current_max_temp} >= 63000 )); then
    new_fan_speed=100
  elif (( ${current_max_temp} >= 60000 )); then
    new_fan_speed=80
  elif (( ${current_max_temp} >= 57000 )); then
    new_fan_speed=64
  elif (( ${current_max_temp} >= 50000 && ${prev_fan_speed} == 64 )); then
    new_fan_speed=64
  else
    new_fan_speed=2
  fi

  if (( ${prev_fan_speed} != ${new_fan_speed} )); then
    #echo "event: adjust; speed: ${new_fan_speed}"
    echo ${new_fan_speed} > ${FAN_SPEED_FILE}
    prev_fan_speed=${new_fan_speed}
  fi

  write_status current_max_temp prev_fan_speed
  sleep 5
done
