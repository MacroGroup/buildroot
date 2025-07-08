#!/bin/bash

if [ $# -lt 1 ]; then
	exit 1
fi

I2C_DEV=$1
CHIP_ADDR=0x38
DIGITS=4
SLEEP_TIME=1

init_display() {
	i2cset -y $I2C_DEV $CHIP_ADDR 0x01 0x00 b
	i2cset -y $I2C_DEV $CHIP_ADDR 0x02 0x3F b
	i2cset -y $I2C_DEV $CHIP_ADDR 0x03 0x03 b
	i2cset -y $I2C_DEV $CHIP_ADDR 0x04 0x01 b
}

DIGIT_MAP=(
	0x7E  # 0
	0x30  # 1
	0x6D  # 2
	0x79  # 3
	0x33  # 4
	0x5B  # 5
	0x5F  # 6
	0x70  # 7
	0x7F  # 8
	0x7B  # 9
)

update_display() {
	local time=$(date +"%H%M")
	local seconds=$(date +"%S")
	local blink_state=$((seconds % 2))

	for (( i=0; i<$DIGITS; i++ )); do
		digit=${time:i:1}
		reg=$((0x20 + i))
		mask=${DIGIT_MAP[$digit]}

		if [[ $i -eq 2 ]]; then
			if [[ $blink_state -eq 0 ]]; then
				mask=$((mask | 0x80))
			fi
		fi

		i2cset -y $I2C_DEV $CHIP_ADDR $reg $mask b
	done
}

init_display
while true; do
	update_display
	sleep $SLEEP_TIME
done
