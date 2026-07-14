#!/usr/bin/env bash

SHARE="/usr/local/share/teflon"
IMAGE="${1:-$SHARE/grace_hopper.bmp}"
MODEL="${2:-$SHARE/mobilenet_v1_1_224_quant.tflite}"
LABELS="${3:-$SHARE/labels_mobilenet_quant_v1_224.txt}"
DELEGATE="${4:-/lib64/libteflon.so}"

check_dependencies() {
	local missing=()
	local modules=( "ai_edge_litert" "PIL" "numpy" )
	local pip_names=( "ai-edge-litert" "Pillow" "numpy" )

	for i in "${!modules[@]}"; do
		module="${modules[$i]}"
		pip_name="${pip_names[$i]}"
		if ! python3 -c "import $module" 2>/dev/null; then
			missing+=("$pip_name")
		fi
	done

	if [ ${#missing[@]} -ne 0 ]; then
		echo "ERROR: Missing required Python packages:"
		printf "  - %s\n" "${missing[@]}"
		echo "Install them with:"
		echo "  pip install --root-user-action=ignore ${missing[*]}"
		exit 1
	fi
}

check_npu() {
	if ls /dev/accel* 1> /dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

run_test() {
	local delegate_arg="$1"
	local label="$2"

	echo "=== $label ==="

	if [ -z "$delegate_arg" ]; then
		python3 "$SHARE/classification.py" -i "$IMAGE" -m "$MODEL" -l "$LABELS"
	else
		python3 "$SHARE/classification.py" -i "$IMAGE" -m "$MODEL" -l "$LABELS" -e "$delegate_arg"
	fi

	echo "------------------------"
}

check_dependencies

if check_npu; then
	has_npu=true
else
	has_npu=false
fi

if $has_npu && [ ! -f "$DELEGATE" ]; then
	has_npu=false
fi

run_test "" "CPU"

if $has_npu; then
	delegate_name=$(basename "$DELEGATE")
	run_test "$DELEGATE" "NPU with $delegate_name"
else
	echo "NPU test skipped!"
fi

exit 0
