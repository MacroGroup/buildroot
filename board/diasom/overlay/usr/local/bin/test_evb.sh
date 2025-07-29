#!/bin/bash

if [ -t 1 ]; then
	COLOR_RESET="\e[0m"
	COLOR_OK="\e[32m"
	COLOR_WARNING="\e[33m"
	COLOR_FAIL="\e[31m"
	COLOR_HEADER="\e[34m"
	COLOR_DEBUG="\e[90m"
	COLOR_INFO="\e[36m"
else
	COLOR_RESET=""
	COLOR_OK=""
	COLOR_WARNING=""
	COLOR_FAIL=""
	COLOR_HEADER=""
	COLOR_DEBUG=""
	COLOR_INFO=""
fi

TEST_FILTER=""
SOURCE="${BASH_SOURCE[0]}"
SCRIPT_NAME=$(basename -- "$SOURCE")
DIR=$(dirname -- "$SOURCE")
SCRIPT_DIR=$(cd -- "$DIR" && pwd)
TEST_DIR="${SCRIPT_DIR}/tests"

TEST_FUNCTIONS=()
TEST_NAMES=()
MAX_NAME_LEN=0

register_test() {
	local test_function="$1"
	local test_name="$2"

	TEST_FUNCTIONS+=("$test_function")
	TEST_NAMES+=("$test_name")

	local name_length=${#test_name}
	[ $name_length -gt $MAX_NAME_LEN ] && MAX_NAME_LEN=$name_length
}

run_tests() {
	local test_count=${#TEST_FUNCTIONS[@]}
	echo -e "${COLOR_HEADER}Starting ${test_count} tests:${COLOR_RESET}"

	local padding=$((MAX_NAME_LEN + 2))

	local current_index=0

	while [ $current_index -lt ${#TEST_FUNCTIONS[@]} ]; do
		local end_index=${#TEST_FUNCTIONS[@]}

		while [ $current_index -lt $end_index ]; do
			local test_function="${TEST_FUNCTIONS[current_index]}"
			local original_test_name="${TEST_NAMES[current_index]}"

			if ! type "$test_function" &> /dev/null; then
				echo -e "[ ${COLOR_FAIL}Error: Test function not found${COLOR_RESET} ]"
				current_index=$((current_index + 1))
				continue
			fi

			local output
			output=$($test_function 2>&1)
			local exit_code=$?

			printf "%-${padding}s : " "$original_test_name"

			if [ $exit_code -eq 0 ]; then
				echo -e "[ ${COLOR_OK}$output${COLOR_RESET} ]"
			elif [ $exit_code -eq 2 ]; then
				echo -e "[ ${COLOR_WARNING}$output${COLOR_RESET} ]"
			else
				echo -e "[ ${COLOR_FAIL}$output${COLOR_RESET} ]"
			fi

			current_index=$((current_index + 1))
		done
	done

	echo -e "${COLOR_HEADER}All tests completed${COLOR_RESET}"
}

self_test() {
	TEST_FUNCTIONS=()
	TEST_NAMES=()
	MAX_NAME_LEN=0

	register_test "test_ok" "Test OK"
	register_test "test_warning" "Test Warning"
	register_test "test_error" "Test Error"

	test_ok() {
		echo "OK"
		return 0
	}

	test_warning() {
		echo "Warning"
		return 2
	}

	test_error() {
		echo "Error"
		return 1
	}

	run_tests

	exit 0
}

if [ $# -gt 0 ]; then
	TEST_FILTER="$1"
	TEST_FILTER=$(echo "$TEST_FILTER" | tr '[:upper:]' '[:lower:]')
fi

if [ $# -gt 1 ]; then
	echo "Usage: $0 [test_filter]" >&2
	exit 1
fi

if [ ! -d "$TEST_DIR" ]; then
	echo -e "${COLOR_FAIL}Error: Test directory $TEST_DIR not found${COLOR_RESET}" >&2
	self_test
fi

echo -e "${COLOR_HEADER}Searching for test modules in $TEST_DIR...${COLOR_RESET}"
found_files=0
loaded_files=0
for test_file in "$TEST_DIR"/*.inc; do
	[ -f "$test_file" ] || continue
	found_files=$((found_files + 1))
	file_basename=$(basename "$test_file" .inc)
	file_basename_lc=$(echo "$file_basename" | tr '[:upper:]' '[:lower:]')

	if [ -n "$TEST_FILTER" ] && [[ ! "$file_basename_lc" =~ $TEST_FILTER ]]; then
		echo -e "${COLOR_DEBUG}  ↺ Skipped: $(basename "$test_file") (filter: $TEST_FILTER)${COLOR_RESET}" >&2
		continue
	fi

	if . "$test_file"; then
		echo -e "${COLOR_DEBUG}  ✓ Loaded: $(basename "$test_file")${COLOR_RESET}"
		loaded_files=$((loaded_files + 1))
	else
		echo -e "${COLOR_FAIL}  ✗ Error loading: $(basename "$test_file")${COLOR_RESET}" >&2
		found_files=$((found_files - 1))
	fi
done

if [ $found_files -eq 0 ]; then
	echo -e "${COLOR_WARNING}No test files found for filter: $TEST_FILTER${COLOR_RESET}" >&2
else
	echo -e "${COLOR_INFO}Found ${found_files} files, loaded ${loaded_files} successfully${COLOR_RESET}"
fi

if [ ${#TEST_FUNCTIONS[@]} -eq 0 ]; then
	if [ -n "$TEST_FILTER" ] && [ $found_files -eq 0 ]; then
		echo -e "${COLOR_WARNING}No test files found for filter: $TEST_FILTER${COLOR_RESET}"
	else
		echo -e "${COLOR_WARNING}No tests registered, running self-test${COLOR_RESET}"
		self_test
	fi
fi

initial_count=${#TEST_FUNCTIONS[@]}
for ((i=0; i<initial_count; i++)); do
	test_func="${TEST_FUNCTIONS[i]}"
	if type "$test_func" &>/dev/null; then
		"$test_func" register >/dev/null 2>&1
	fi
done

run_tests

exit 0
