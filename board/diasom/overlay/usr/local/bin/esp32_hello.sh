#!/bin/sh

DEV=/dev/ttymxc0
MOD=/tmp/esp32

[ -e $DEV ] || { echo "Script is not supported on this platform!"; exit 1; }

# Ensure no listener on serial port
killall tail 2&> /dev/null

# Turn Power OFF
gpioset gpiochip3 31=0
sleep 1

# Install UART listener
tail -f $DEV &
PID=$!

MODE=$(cat $MOD 2&> /dev/null)
# Check if already downloaded
if [ "$MODE" != "hello" ]; then
	# Switch to UART download mode
	gpioset gpiochip3 28=0
	sleep 0.1

	# Turn Power ON
	gpioset gpiochip3 31=1
	sleep 1.5

	esptool.py -p $DEV --chip esp32 -b 115200 \
	--before default_reset --after hard_reset \
	write_flash --flash_mode dio --flash_size 2MB --flash_freq 40m \
	0x1000 /usr/local/share/esp32/bootloader.bin \
	0x8000 /usr/local/share/esp32/partition-table.bin \
	0x10000 /usr/local/share/esp32/hello_world.bin || exit 1

	# Turn Power OFF
	gpioset gpiochip3 31=0
	sleep 1

	echo -n hello > $MOD
fi

# Switch to SPI download mode
gpioset gpiochip3 28=1
sleep 0.1

# Turn Power ON
gpioset gpiochip3 31=1
sleep 0.1

# Wait for any key
while [ true ]; do
	read -t 1 -n 1
	if [ $? = 0 ]; then
		break;
	fi
done

# Remove UART listener
kill $PID 2&> /dev/null

# Turn Power OFF
gpioset gpiochip3 31=0

exit 0
