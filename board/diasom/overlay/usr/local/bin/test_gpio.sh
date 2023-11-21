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
		exit 1
	fi
}

test_getval()
{
	VAL=$(cat /sys/class/gpio/gpio$1/value)
	if [ $VAL -ne "$2" ]; then
		echo "Read/Write mismatch $VAL != $2 !"
		exit 1
	fi
}

test_gpio_pair_one()
{
	setup_gpio $1
	printf " => "
	setup_gpio $2
	printf ": "

	if [ ! -d /sys/class/gpio/gpio$1 ]; then
		echo "Setup error 1!"
		exit 1
	fi

	if [ ! -d /sys/class/gpio/gpio$2 ]; then
		echo "Setup error 2!"
		exit 1
	fi

	setup_direction $1 "out"
	test_setval $1 0
	test_getval $2 0
	test_setval $1 1
	test_getval $2 1
}

test_gpio_pair()
{
	GPIOBASE=0
	if grep -Eq 'diasom,ds-imx8m-evb' /proc/device-tree/compatible; then
		GPIOBASE=32
	fi

	GPIO1=$(expr $1 * 32 + $2 - $GPIOBASE)
	GPIO2=$(expr $3 * 32 + $4 - $GPIOBASE)
	test_gpio_pair_one $GPIO1 $GPIO2
	echo "OK"

	test_gpio_pair_one $GPIO2 $GPIO1
	echo "OK"
}

test_gpio_imx8m()
{
	echo "Testing GPIO lines:"

	# X8.1 (UART4_TXD GPIO5.29)	<=>	X8.2 (UART4_RXD GPIO5.28)
	test_gpio_pair 5 29 5 28

	# X9.1 (UART3_TXD GPIO5.27)	<=>	X9.2 (UART3_RXD GPIO5.26)
	test_gpio_pair 5 27 5 26

	# X13.7 (I2C4_SDA GPIO5.21)	<=>	X13.8 (I2C4_SCL GPIO5.20)
	test_gpio_pair 5 21 5 20

	# X13.10 (SAI2_RXFS GPIO4.21)	<=>	X15.5 (SPDIF_RX GPIO5.4)
	test_gpio_pair 4 21 5 4

	# X13.11 (SAI2_TXD GPIO4.26)	<=>	X13.12 (SAI2_MCLK GPIO4.27)
	test_gpio_pair 4 26 4 27

	# X13.13 (SAI2_TXC GPIO4.25)	<=>	X13.14 (SAI2_RXD GPIO4.23)
	test_gpio_pair 4 25 4 23

	# X13.15 (SAI2_RXC GPIO4.22)	<=>	X13.16 (SAI2_TXFS GPIO4.24)
	test_gpio_pair 4 22 4 24

	# X14.3 (GPIO1_IO0 GPIO1.0)	<=>	X14.4 (GPIO1_IO1 GPIO1.1)
	test_gpio_pair 1 0 1 1

	# X14.6 (GPIO1_IO4 GPIO1.4)	<=>	X14.7 (GPIO1_IO5 GPIO1.5)
	test_gpio_pair 1 4 1 5

	# X14.13 (GPIO1_IO11 GPIO1.11)	<=>	X14.15 (GPIO1_IO13 GPIO1.13)
	test_gpio_pair 1 11 1 13

	# X15.3 (SPDIF_CLK GPIO5.5)	<=>	X15.4 (SPDIF_TX GPIO5.3)
	test_gpio_pair 5 5 5 3

	# X15.9 (ESCPI2_SCLK GPIO5.10)	<=>	X15.10 (ESCPI2_MOSI GPIO5.11)
	test_gpio_pair 5 10 5 11

	# X15.11 (ESCPI2_MISO GPIO5.12)	<=>	X15.12 (ESCPI2_CS0 GPIO5.13)
	test_gpio_pair 5 12 5 13

	# X15.13 (ECSPI1_SCLK GPIO5.6)	<=>	X15.14 (ESCPI1_MOSI GPIO5.7)
	test_gpio_pair 5 6 5 7

	# X15.15 (ESCPI1_MISO GPIO5.8)	<=>	X15.16 (ESCPI1_CS0 GPIO5.9)
	test_gpio_pair 5 8 5 9

	echo "Done!"
}

if grep -Eq 'diasom,ds-imx8m-evb' /proc/device-tree/compatible; then
	test_gpio_imx8m
	exit 0
fi

echo "Script canont be used on this platform!"

exit 1
