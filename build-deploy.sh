#!/usr/bin/env bash

REMOTE_USER="dietpi"
REMOTE_HOST="192.168.1.70"
REMOTE_BASE_PATH="/home/dietpi/calendar-clock-swift"
SSH_KEY="$HOME/.ssh/raspberry"
BINARY_NAME="CalendarClock"

usage() {
    echo "Usage: $0 [-i|--ip REMOTE_IP] [-p|--path REMOTE_BASE_PATH] [-u|--user REMOTE_USER]"
    echo
    echo "  -i, --ip     Remote machine IP address (default: ${REMOTE_HOST})"
    echo "  -p, --path   Base path on remote machine (default: ${REMOTE_BASE_PATH})"
    echo "               Note: '.build/aarch64-unknown-linux-gnu/release' is always appended"
    echo "  -u, --user   Remote SSH user (default: ${REMOTE_USER})"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ip)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -p|--path)
            REMOTE_BASE_PATH="${2%/}"  # strip trailing slash if present
            shift 2
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

check_host_system() {
    local host_os host_arch

    host_os=$(uname -s)
    host_arch=$(uname -m)

    if [[ "$host_os" != "Linux" || ("$host_arch" != "aarch64" && "$host_arch" != "arm64") ]]; then
        echo "Error: this script may only be run on arm Linux hosts."
        echo "Detected: OS=$host_os ARCH=$host_arch"
        exit 1
    fi
}

check_host_system

REMOTE_BUILD_SUFFIX=".build/aarch64-unknown-linux-gnu/release"
REMOTE_FULL_PATH="${REMOTE_BASE_PATH}/${REMOTE_BUILD_SUFFIX}"

# Clean up only the specific agent spawned by this script run
cleanup_agent() {
    if [ -n "$SSH_AGENT_PID" ]; then
        echo "Cleaning up ssh-agent (PID: $SSH_AGENT_PID)..."
        kill "$SSH_AGENT_PID" 2>/dev/null
    fi
}

# Trap EXIT (which covers normal end of script, script failures, and Ctrl+C / SIGINT)
trap cleanup_agent EXIT

# Start the agent and capture its variables
eval "$(ssh-agent)"
ssh-add "$SSH_KEY"

# build
swift build -c release --static-swift-stdlib

# copy
echo "Uploading ..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_FULL_PATH}"
scp ".build/aarch64-unknown-linux-gnu/release/${BINARY_NAME}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_FULL_PATH}"
