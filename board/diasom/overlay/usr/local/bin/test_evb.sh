#!/bin/bash
# shellcheck disable=SC1090,SC2329

if [ -t 1 ] && [ -z "${NO_COLOR}" ]; then
	COLOR_RESET="\e[0m"
	COLOR_OK="\e[32m"
	COLOR_WARNING="\e[33m"
	COLOR_FAIL="\e[31m"
	COLOR_HEADER="\e[34m"
	COLOR_DEBUG="\e[90m"
else
	COLOR_RESET=""
	COLOR_OK=""
	COLOR_WARNING=""
	COLOR_FAIL=""
	COLOR_HEADER=""
	COLOR_DEBUG=""
fi

TEST_FILTER=""
SOURCE="${BASH_SOURCE[0]}"
DIR=$(dirname -- "$SOURCE")
SCRIPT_DIR=$(cd -- "$DIR" && pwd)
TEST_DIR="${SCRIPT_DIR}/tests"

declare -a TEST_QUEUE
declare -a TEST_NAMES
declare -a TEST_LEVELS
MAX_NAME_LEN=38

check_dependencies() {
	local module=$1
	shift
	local deps=("$@")

	local base_deps
	base_deps=(@register_test)
	base_deps+=(awk basename bc cat cut dmesg echo find grep head ls mktemp mount printf readlink sort stat tail tr)
	deps+=("${base_deps[@]}")

	local sorted_deps
	mapfile -t sorted_deps < <(printf "%s\n" "${deps[@]}" | sort -u)
	if [ ${#sorted_deps[@]} -eq 0 ]; then
		return 0
	fi

	for cmd in "${sorted_deps[@]}"; do
		if [[ "$cmd" == @* ]]; then
			local func_name="${cmd#@}"
			if ! declare -f "$func_name" &>/dev/null; then
				echo "Error [$module]: function $func_name not defined"
				return 1
			fi
		else
			if ! command -v "$cmd" &>/dev/null; then
				echo "Error [$module]: $cmd not installed"
				return 1
			fi
		fi
	done

	return 0
}

register_test() {
	local test_function="$1"
	local test_name="$2"
	local test_level="${3:-0}"

	if [[ "$test_function" == @* ]]; then
		test_function="${test_function#@}"
		TEST_QUEUE=("$test_function" "${TEST_QUEUE[@]}")
		TEST_NAMES=("$test_name" "${TEST_NAMES[@]}")
		TEST_LEVELS=("$test_level" "${TEST_LEVELS[@]}")
	else
		TEST_QUEUE+=("$test_function")
		TEST_NAMES+=("$test_name")
		TEST_LEVELS+=("$test_level")
	fi

	local padded_name=""
	local i
	for ((i=0; i<test_level; i++)); do
		padded_name+="  "
	done

	local name_length=${#test_name}
	[ "$name_length" -gt "$MAX_NAME_LEN" ] && MAX_NAME_LEN=$name_length
}

run_tests() {
	echo -e "${COLOR_HEADER}Starting tests:${COLOR_RESET}"

	local count_ok=0
	local count_warning=0
	local count_error=0

	local output_file
	output_file=$(mktemp) || {
		echo -e "${COLOR_FAIL}Failed to create temporary file${COLOR_RESET}"
		return 1
	}

	while [ ${#TEST_QUEUE[@]} -gt 0 ]; do
		local test_function="${TEST_QUEUE[0]}"
		local original_test_name="${TEST_NAMES[0]}"
		local test_level="${TEST_LEVELS[0]}"

		TEST_QUEUE=("${TEST_QUEUE[@]:1}")
		TEST_NAMES=("${TEST_NAMES[@]:1}")
		TEST_LEVELS=("${TEST_LEVELS[@]:1}")

		: > "$output_file"

		$test_function >"$output_file" 2>&1
		local exit_code=$?

		local output
		output=$(<"$output_file")

		local padding_spaces=""
		local i
		for ((i=0; i<test_level; i++)); do
			padding_spaces+="  "
		done
		local displayed_name="${padding_spaces}${original_test_name}"

		local temp_padding="$MAX_NAME_LEN"
		printf "%-${temp_padding}s : " "$displayed_name"

		if [ $exit_code -eq 0 ]; then
			echo -e "[ ${COLOR_OK}$output${COLOR_RESET} ]"
			count_ok=$((count_ok + 1))
		elif [ $exit_code -eq 2 ]; then
			echo -e "[ ${COLOR_WARNING}$output${COLOR_RESET} ]"
			count_warning=$((count_warning + 1))
		else
			echo -e "[ ${COLOR_FAIL}$output${COLOR_RESET} ]"
			count_error=$((count_error + 1))
		fi
	done

	rm -f "$output_file"

	echo -e "${COLOR_HEADER}All tests completed${COLOR_RESET}: ${COLOR_OK}Passed: $count_ok${COLOR_RESET}, ${COLOR_WARNING}Warnings: $count_warning${COLOR_RESET}, ${COLOR_FAIL}Errors: $count_error${COLOR_RESET}"
}

register_self_tests() {
	test_deep2() {
		echo "OK"
		return 0
	}

	test_deep() {
		register_test "test_deep2" "Test Deep Register Padding" 1
		echo "OK"
		return 0
	}

	test_color_ok() {
		register_test "test_deep" "Test Deep Register"
		echo "OK"
		return 0
	}

	test_color_warning() {
		echo "Warning"
		return 2
	}

	test_color_error() {
		echo "Error"
		return 1
	}

	register_test "test_color_ok" "Test Color \"OK\""
	register_test "test_color_warning" "Test Color \"Warning\""
	register_test "test_color_error" "Test Color \"Error\""
}

check_dependencies "CORE" || exit 1

if [ $# -gt 0 ]; then
	TEST_FILTER="$1"
	TEST_FILTER=$(echo "$TEST_FILTER" | tr '[:upper:]' '[:lower:]')
fi

if [ $# -gt 1 ]; then
	echo "Usage: $0 [test_filter]" >&2
	exit 1
fi

shopt -s nullglob

if [ ! -d "${TEST_DIR:-}" ]; then
	echo -e "${COLOR_FAIL}Error: Test directory $TEST_DIR not found${COLOR_RESET}" >&2
else
	echo -e "${COLOR_HEADER}Loading functions from $TEST_DIR...${COLOR_RESET}"

	func_files=("$TEST_DIR"/*.inc)
	if [ ${#func_files[@]} -eq 0 ] || [ ! -f "${func_files[0]}" ]; then
		echo -e "${COLOR_DEBUG}  No functions defined${COLOR_RESET}"
	else
		for func_file in "$TEST_DIR"/*.inc; do
			[ -f "$func_file" ] || continue

			if . "$func_file"; then
				echo -e "${COLOR_DEBUG}  ✓ Loaded: $(basename "$func_file")${COLOR_RESET}"
			else
				echo -e "${COLOR_FAIL}  ✗ Error loading: $(basename "$func_file")${COLOR_RESET}" >&2
			fi
		done
	fi

	echo -e "${COLOR_HEADER}Loading test modules from $TEST_DIR...${COLOR_RESET}"

	for test_file in "$TEST_DIR"/*.tst; do
		[ -f "$test_file" ] || continue

		file_basename=$(basename "$test_file" .tst)
		file_basename_lc=$(echo "$file_basename" | tr '[:upper:]' '[:lower:]')

		if [ -n "$TEST_FILTER" ] && [[ ! "$file_basename_lc" =~ $TEST_FILTER ]]; then
			echo -e "${COLOR_DEBUG}  ↺ Skipped: $(basename "$test_file") (filter: $TEST_FILTER)${COLOR_RESET}" >&2
			continue
		fi

		if . "$test_file"; then
			echo -e "${COLOR_DEBUG}  ✓ Loaded: $(basename "$test_file")${COLOR_RESET}"
		else
			echo -e "${COLOR_FAIL}  ✗ Error loading: $(basename "$test_file")${COLOR_RESET}" >&2
		fi
	done
fi

if [ ${#TEST_QUEUE[@]} -eq 0 ]; then
	echo -e "${COLOR_DEBUG}No tests registered, running self-tests${COLOR_RESET}"
	register_self_tests
fi

run_tests

exit 0
