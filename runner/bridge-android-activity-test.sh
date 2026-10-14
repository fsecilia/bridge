#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -eu

BRIDGE_ANDROID_COMMAND_NAME=bridge-android-activity-test
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
. "$script_dir/bridge-android-common.sh"

if [ "$#" -ne 5 ]; then
    bridge_android_fail 'usage: bridge-android-activity-test.sh <adb> <abi> <apk> <application-id> <activity>'
fi
bridge_android_adb=$1
bridge_android_abi=$2
apk=$3
application_id=$4
activity=$5

bridge_android_validate_adb
bridge_android_validate_abi
if [ ! -f "$apk" ]; then
    bridge_android_fail "APK does not exist: $apk (build its application target before CTest)"
fi

serial=$(bridge_android_select_device)
log_file=$(mktemp) || bridge_android_fail 'could not create an Android test log file'
installed=0
cleanup()
{
    result=$?
    trap - EXIT HUP INT TERM
    if [ "$installed" -eq 1 ]; then
        if ! "$bridge_android_adb" -s "$serial" shell am force-stop "$application_id" >/dev/null 2>&1; then
            printf '%s\n' "Bridge Android Activity test: cleanup could not stop $application_id" >&2
            result=1
        fi
        if ! "$bridge_android_adb" -s "$serial" uninstall "$application_id" >/dev/null 2>&1; then
            printf '%s\n' "Bridge Android Activity test: cleanup could not uninstall $application_id" >&2
            result=1
        fi
    fi
    if ! rm -f "$log_file"; then
        printf '%s\n' "Bridge Android Activity test: cleanup could not remove temporary log $log_file" >&2
        result=1
    fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if ! "$bridge_android_adb" -s "$serial" install -r "$apk"; then
    bridge_android_fail "APK install failed for $application_id on $serial"
fi
installed=1
"$bridge_android_adb" -s "$serial" shell am force-stop "$application_id" >/dev/null || \
    bridge_android_fail "could not stop $application_id before testing"
"$bridge_android_adb" -s "$serial" logcat -c || bridge_android_fail 'could not clear stale logcat messages'
"$bridge_android_adb" -s "$serial" shell am start -n "$application_id/$activity" || \
    bridge_android_fail "could not start $application_id/$activity"

# Poll logs rather than the exit status of `am start`: that status only confirms
# launch acceptance. The terminal record comes from inside the test process.
timeout_seconds=${BRIDGE_ANDROID_TEST_TIMEOUT_SECONDS:-30}
case $timeout_seconds in
    ''|*[!0-9]*) bridge_android_fail "invalid BRIDGE_ANDROID_TEST_TIMEOUT_SECONDS: $timeout_seconds" ;;
esac
if [ "$timeout_seconds" -eq 0 ]; then
    bridge_android_fail 'BRIDGE_ANDROID_TEST_TIMEOUT_SECONDS must be positive'
fi
attempts=$((timeout_seconds * 4))
attempt=0
while [ "$attempt" -lt "$attempts" ]; do
    if ! "$bridge_android_adb" -s "$serial" logcat -d -v brief >"$log_file"; then
        bridge_android_fail 'could not retrieve Activity test logcat'
    fi
    if grep -Fq 'BRIDGE_ACTIVITY_TEST_RESULT' "$log_file"; then
        # Require an explicit START record as well as exactly one terminal record.
        grep -F 'BRIDGE_ACTIVITY_TEST' "$log_file"
        terminal_count=$(grep -Fc 'BRIDGE_ACTIVITY_TEST_RESULT' "$log_file")
        if [ "$terminal_count" -ne 1 ]; then
            bridge_android_fail "received $terminal_count terminal result records; expected one"
        fi
        if ! grep -Fq 'BRIDGE_ACTIVITY_TEST_STARTED' "$log_file"; then
            bridge_android_fail 'terminal record appeared without a test-start record'
        fi
        if grep -Fq 'BRIDGE_ACTIVITY_TEST_RESULT PASS ' "$log_file"; then
            printf '%s\n' "Bridge Android Activity test passed on $serial"
            exit 0
        fi
        bridge_android_fail 'Activity tests reported failure (see results above)'
    fi
    attempt=$((attempt + 1))
    sleep 0.25
done
printf '%s\n' 'Bridge Android Activity test: no terminal record; recent logcat follows:' >&2
tail -n 80 "$log_file" >&2
bridge_android_fail "Activity did not finish its tests within ${timeout_seconds}s"
