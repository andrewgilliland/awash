#!/usr/bin/env bash
# Sourced by the quality scripts; expects GODOT_BIN to be set.

# Runs Godot with a time limit so a script that never reaches quit() (for example after a
# compile error) fails the gate instead of hanging it. Override with GODOT_TIMEOUT_SECONDS.
run_godot() {
	local limit="${GODOT_TIMEOUT_SECONDS:-120}"
	"$GODOT_BIN" "$@" &
	local godot_pid=$!

	(
		for ((elapsed = 0; elapsed < limit; elapsed++)); do
			sleep 1
			kill -0 "$godot_pid" 2>/dev/null || exit 0
		done
		echo "Godot did not exit within ${limit}s; stopping it." >&2
		kill "$godot_pid" 2>/dev/null
	) &
	local watchdog_pid=$!

	local status=0
	wait "$godot_pid" || status=$?
	# Stop the watchdog now rather than waiting out its current one-second sleep.
	kill "$watchdog_pid" 2>/dev/null || true
	wait "$watchdog_pid" 2>/dev/null || true
	return "$status"
}
