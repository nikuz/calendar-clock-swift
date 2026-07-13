#!/usr/bin/env bash

kill_ssh_agents() {
    local agent_pids
    agent_pids=$(pgrep -u "$(id -u)" ssh-agent)

    if [ -n "$agent_pids" ]; then
        echo "Killing existing ssh-agent(s) with PID: $agent_pids"
        kill $agent_pids 
    fi
}

kill_ssh_agents

eval "$(ssh-agent)"
ssh-add ~/.ssh/raspberry

# build
swift build -c release --static-swift-stdlib

# archive
tar -czvf calendar-clock-swift.tar.gz .build/aarch64-unknown-linux-gnu/release

# copy
scp calendar-clock-swift.tar.gz dietpi@192.168.1.70:/home/dietpi

# unzip on the remote machine
ssh dietpi@192.168.1.70 "tar -xzf /home/dietpi/calendar-clock-swift.tar.gz -C /home/dietpi/calendar-clock-swift"

kill_ssh_agents