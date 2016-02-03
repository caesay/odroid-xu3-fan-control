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
TEMP_UP_STEPS=(2  57000  62000  67000  72000  77000  82000  87000)
TEMP_DOWN_STEPS=(2  50000  55000  60000  65000  70000  75000  80000)
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
  echo -ne "\r[Status] Temp: $(($1/1000))C, Fan Speed: $((${FAN_STEPS[$2]}*100/255))%"
  printf "%0.s " {1..10}
}

function write_step {
  echo ${FAN_STEPS[$1]} > ${FAN_SPEED_FILE}
}

function get_speed_up {
  for x in 7 6 5 4 3 2 1 0
  do
    if (( $1 >= ${TEMP_UP_STEPS[${x}]} )); then
      return $x
    fi
  done
  return 1
}

function get_speed_down {
  for x in 7 6 5 4 3 2 1 0
  do
    if (( $1 >= ${TEMP_DOWN_STEPS[${x}]} )); then
      return $x
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

# init fan 
get_speed_up current_max_temp
prev_step=$?
prev_time=$SECONDS
echo 0 > ${FAN_MODE_FILE}
write_step prev_step
write_status current_max_temp prev_step

while [ true ];
do
  sleep 5

  current_max_temp=`cat ${TEMPERATURE_FILE} | cut -d: -f2 | sort -nr | head -1`
  get_speed_up current_max_temp
  new_step=$?

  if (( $new_step < $prev_step )); then
    get_speed_down current_max_temp
    new_step=$?
  fi

  if (( $new_step > $prev_step )); then
    write_step new_step
    prev_step=$new_step
    prev_time=$SECONDS
  elif (( $new_step < $prev_step )) && (( $SECONDS-$prev_time > 20 )); then
    write_step new_step
    prev_step=$new_step
    prev_time=$SECONDS
  fi

  write_status current_max_temp prev_step
done
