#!/bin/bash
#
# Avaota A1 First Boot Setup
# Runs once on first boot to pull latest Home Assistant and OpenClaw.
# Managed by avaota-first-setup.service (ConditionPathExists guard).
#

set -euo pipefail

LOG_TAG="avaota-first-setup"
SETUP_DONE_MARKER="${SETUP_DONE_MARKER:-/var/lib/avaota-first-setup-done}"
SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"
SETUP_TIMER_UNIT="${SETUP_TIMER_UNIT:-avaota-first-setup.timer}"

log() {
    echo "[${LOG_TAG}] $*"
    logger -t "${LOG_TAG}" "$*"
}

# shellcheck disable=SC1091
. /usr/local/lib/avaota-blz-zha.sh

network_ready() {
    if command -v nm-online >/dev/null 2>&1 && ! nm-online -q -t 10; then
        log "Network is not ready; setup remains pending for timer retry"
        return 1
    fi

    if getent hosts ghcr.io >/dev/null 2>&1; then
        log "Network is up"
        return 0
    fi

    log "Network is not ready; setup remains pending for timer retry"
    return 1
}

mark_setup_done() {
    mkdir -p "$(dirname "${SETUP_DONE_MARKER}")"
    touch "${SETUP_DONE_MARKER}"
    if ! "${SYSTEMCTL_BIN}" --no-block stop "${SETUP_TIMER_UNIT}"; then
        log "Could not stop ${SETUP_TIMER_UNIT}; completion marker will prevent future setup runs"
    fi
}

setup_homeassistant() {
    log "Pulling latest Home Assistant Docker image..."
    docker pull ghcr.io/home-assistant/home-assistant:stable || return $?

    mkdir -p /opt/homeassistant/config || return $?

    if docker container inspect homeassistant >/dev/null 2>&1; then
        log "Home Assistant container already exists"
    else
        log "Creating Home Assistant container..."
        docker create \
            --name homeassistant \
            --restart unless-stopped \
            --network host \
            --privileged \
            -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
            -v /opt/homeassistant/config:/config \
            -v /run/dbus:/run/dbus:ro \
            ghcr.io/home-assistant/home-assistant:stable || return $?
    fi

    log "Starting Home Assistant..."
    if [ "$(docker inspect -f '{{.State.Running}}' homeassistant 2>/dev/null || echo false)" != "true" ]; then
        docker start homeassistant || return $?
    fi

    log "Home Assistant is running at http://localhost:8123"
}

setup_openclaw() {
    log "Installing latest OpenClaw..."
    npm install -g openclaw@latest || return $?

    log "OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'version check skipped')"
    log "Run 'openclaw onboard --install-daemon' to complete setup"
}

run_setup() {
    local name="$1"
    shift

    if "$@"; then
        log "${name} setup completed"
        return 0
    else
        local status=$?
        log "${name} setup failed with exit code ${status}; remaining setup steps will continue"
        return "${status}"
    fi
}

main() {
    log "=== Avaota A1 First Boot Setup ==="
    log "Date: $(date)"

    if ! network_ready; then
        exit 0
    fi

    local setup_failed=0
    run_setup "Home Assistant" setup_homeassistant || setup_failed=1
    run_setup "BLZ/ZHA" setup_zha_blz || setup_failed=1
    run_setup "OpenClaw" setup_openclaw || setup_failed=1

    if [ "${setup_failed}" -ne 0 ]; then
        log "First boot setup incomplete; timer/service will retry pending steps"
        exit 1
    fi

    mark_setup_done

    log "=== First boot setup complete ==="
    log "Home Assistant: http://<this-device-ip>:8123"
    log "  -> Built-in ZHA is registered for BLZ; add ZHA integration in UI"
    log "  -> BLZ dongles should auto-detect at 2000000 baud"
    log "OpenClaw: run 'openclaw onboard --install-daemon' to configure"
}

main "$@"
