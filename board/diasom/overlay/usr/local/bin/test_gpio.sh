#!/bin/sh

if ! grep -Eq '\bboot-test\b' /proc/cmdline; then
	echo "Script can be used within test environment only"
	exit 1
fi

print_gpio()
{
	FIRSTBANK=0
	if grep -Eq 'diasom,ds-imx8m-evb' /proc/device-tree/compatible; then
		FIRSTBANK=1
	fi

	BASE=$(expr $1 / 32)
	BASE=$(expr $BASE + $FIRSTBANK)
	LINE=$(expr $1 % 32)

	printf "GPIO$BASE.$LINE"
}

setup_direction()
{
	if [ -d /sys/class/gpio/gpio$1 ]; then
		echo -n $2 > /sys/class/gpio/gpio$1/direction
		echo -n "0" > /sys/class/gpio/gpio$1/active_low
	fi
}

setup_gpio()
{
	echo -n $1 > /sys/class/gpio/export 2&>/dev/null
	setup_direction $1 "in"
	print_gpio $1
}

test_setval()
{
	echo -n "$2" > /sys/class/gpio/gpio$1/value

	VAL=$(cat /sys/class/gpio/gpio$1/value)
	if [ $VAL -ne "$2" ]; then
		echo "Cannot set value $2"
		setup_direction $1 "in"
		exit 1
	fi
}

test_getval()
{
	VAL=$(cat /sys/class/gpio/gpio$2/value)
	if [ $VAL -ne "$3" ]; then
		echo "Read/Write mismatch $VAL != $3 !"
		setup_direction $1 "in"
		exit 1
	fi
}

test_gpio()
{
	setup_gpio $1
	printf " => "
	setup_gpio $2
	printf ": "

	if [ ! -d /sys/class/gpio/gpio$1 ]; then
		echo "Source GPIO setup error!"
		exit 1
	fi

	if [ ! -d /sys/class/gpio/gpio$2 ]; then
		echo "Destination GPIO Setup error!"
		exit 1
	fi

	setup_direction $1 "out"

	test_setval $1 0
	test_getval $1 $2 0

	test_setval $1 1
	test_getval $1 $2 1

	setup_direction $1 "in"
}

test_gpio_pair()
{
	GPIOBASE=0
	if grep -Eq 'diasom,ds-imx8m-evb' /proc/device-tree/compatible; then
		GPIOBASE=32
	fi

	GPIO1=$(expr $1 * 32 + $2 - $GPIOBASE)
	GPIO2=$(expr $3 * 32 + $4 - $GPIOBASE)

	test_gpio $GPIO1 $GPIO2
	echo "OK"

	test_gpio $GPIO2 $GPIO1
	echo "OK"
}

test_gpio_trio()
{
	GPIOBASE=0
	if grep -Eq 'diasom,ds-imx8m-evb' /proc/device-tree/compatible; then
		GPIOBASE=32
	fi

	GPIO1=$(expr $1 * 32 + $2 - $GPIOBASE)
	GPIO2=$(expr $3 * 32 + $4 - $GPIOBASE)
	GPIO3=$(expr $5 * 32 + $6 - $GPIOBASE)

	test_gpio $GPIO1 $GPIO2
	echo "OK"

	test_gpio $GPIO2 $GPIO1
	echo "OK"

	test_gpio $GPIO1 $GPIO3
	echo "OK"
}

test_gpio_imx8m()
{
	echo "Testing GPIO lines:"

	# X8.1 (UART4_TXD GPIO5.29)	<=R1K=>	X8.2 (UART4_RXD GPIO5.28)
	test_gpio_pair 5 29 5 28

	# X9.1 (UART3_TXD GPIO5.27)	<=R1K=>	X9.2 (UART3_RXD GPIO5.26)
	test_gpio_pair 5 27 5 26

	# X13.7 (I2C4_SDA GPIO5.21)	<=R1K=>	X13.8 (I2C4_SCL GPIO5.20)
	# X13.10 (SAI2_RXFS GPIO4.21)	<=R1K=>	--> X13.8
	test_gpio_trio 5 20 5 21 4 21

	# X13.11 (SAI2_TXD GPIO4.26)	<=R1K=>	X13.12 (SAI2_MCLK GPIO4.27)
	test_gpio_pair 4 26 4 27

	# X13.13 (SAI2_TXC GPIO4.25)	<=R1K=>	X13.14 (SAI2_RXD GPIO4.23)
	test_gpio_pair 4 25 4 23

	# X13.15 (SAI2_RXC GPIO4.22)	<=R1K=>	X13.16 (SAI2_TXFS GPIO4.24)
	test_gpio_pair 4 22 4 24

	# X14.3 (GPIO1_IO0 GPIO1.0)	<=R1K=>	X14.4 (GPIO1_IO1 GPIO1.1)
	test_gpio_pair 1 0 1 1

	# X14.6 (GPIO1_IO4 GPIO1.4)	<=R1K=>	X14.7 (GPIO1_IO5 GPIO1.5)
	test_gpio_pair 1 4 1 5

	# X14.13 (GPIO1_IO11 GPIO1.11)	<=R1K=>	X14.15 (GPIO1_IO13 GPIO1.13)
	test_gpio_pair 1 11 1 13

	# X15.3 (SPDIF_CLK GPIO5.5)	<=R1K=>	X15.4 (SPDIF_TX GPIO5.3)
	# X15.5	(SPDIF_RX GPIO5.4)	<=R1K=>	--> X15.3
	test_gpio_trio 5 5 5 3 5 4

	# X15.9 (ESCPI2_SCLK GPIO5.10)	<=R1K=>	X15.10 (ESCPI2_MOSI GPIO5.11)
	test_gpio_pair 5 10 5 11

	# X15.11 (ESCPI2_MISO GPIO5.12)	<=R1K=>	X15.12 (ESCPI2_CS0 GPIO5.13)
	test_gpio_pair 5 12 5 13

	# X15.13 (ECSPI1_SCLK GPIO5.6)	<=R1K=>	X15.14 (ESCPI1_MOSI GPIO5.7)
	test_gpio_pair 5 6 5 7

	# X15.15 (ESCPI1_MISO GPIO5.8)	<=R1K=>	X15.16 (ESCPI1_CS0 GPIO5.9)
	test_gpio_pair 5 8 5 9

	echo "Done!"
}

if grep -Eq 'diasom,ds-imx8m-evb' /proc/device-tree/compatible; then
	test_gpio_imx8m
	exit 0
fi

echo "Script canont be used on this platform!"

exit 1
