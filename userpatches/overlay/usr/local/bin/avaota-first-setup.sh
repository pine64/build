#!/bin/bash
#
# Avaota A1 First Boot Setup
# Runs once on first boot to pull latest Home Assistant and OpenClaw.
# Managed by avaota-first-setup.service (ConditionPathExists guard).
#

set -euo pipefail

LOG_TAG="avaota-first-setup"

log() {
    echo "[${LOG_TAG}] $*"
    logger -t "${LOG_TAG}" "$*"
}

wait_for_network() {
    local retries=30
    while [ $retries -gt 0 ]; do
        if ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
            log "Network is up"
            return 0
        fi
        log "Waiting for network... (${retries} retries left)"
        sleep 5
        retries=$((retries - 1))
    done
    log "ERROR: Network not available after 150s"
    return 1
}

setup_homeassistant() {
    log "Pulling latest Home Assistant Docker image..."
    docker pull ghcr.io/home-assistant/home-assistant:stable

    log "Creating Home Assistant container..."
    mkdir -p /opt/homeassistant/config
    docker create \
        --name homeassistant \
        --restart unless-stopped \
        --network host \
        --privileged \
        -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
        -v /opt/homeassistant/config:/config \
        -v /run/dbus:/run/dbus:ro \
        ghcr.io/home-assistant/home-assistant:stable

    log "Starting Home Assistant..."
    docker start homeassistant

    log "Home Assistant is running at http://localhost:8123"
}

setup_zha_blz() {
    log "Installing ZHA BLZ custom component for Home Assistant..."
    local ha_config="/opt/homeassistant/config"
    mkdir -p "${ha_config}/custom_components"

    # Clone and copy only the custom_components/zha directory
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    git clone --depth 1 https://github.com/fangzheli/haos_custom_zha_blz.git "${tmp_dir}"
    cp -r "${tmp_dir}/custom_components/zha" "${ha_config}/custom_components/"
    rm -rf "${tmp_dir}"

    log "ZHA BLZ installed to ${ha_config}/custom_components/zha"
    log "Restarting Home Assistant to load BLZ component..."
    docker restart homeassistant
}

setup_openclaw() {
    log "Installing latest OpenClaw..."
    npm install -g openclaw@latest

    log "OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'version check skipped')"
    log "Run 'openclaw onboard --install-daemon' to complete setup"
}

main() {
    log "=== Avaota A1 First Boot Setup ==="
    log "Date: $(date)"

    wait_for_network

    setup_homeassistant
    setup_zha_blz
    setup_openclaw

    log "=== First boot setup complete ==="
    log "Home Assistant: http://<this-device-ip>:8123"
    log "  -> ZHA BLZ component pre-installed, add integration in UI"
    log "  -> Use /dev/serial/by-id/... for dongle path"
    log "OpenClaw: run 'openclaw onboard --install-daemon' to configure"
}

main "$@"
