#!/bin/bash
# ===========================================================================
# uninstall_systemd.sh — Remove the systemd user timer (Linux)
# ===========================================================================

set -euo pipefail

SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="sharepoint-timesheet-bot"

echo "🗑️  Uninstalling SharePoint Timesheet Bot systemd timer..."
echo ""

# ---- Stop and disable the timer -------------------------------------------
if systemctl --user is-active --quiet "${SERVICE_NAME}.timer" 2>/dev/null; then
    echo "⏳ Stopping timer..."
    systemctl --user stop "${SERVICE_NAME}.timer"
fi

if systemctl --user is-enabled --quiet "${SERVICE_NAME}.timer" 2>/dev/null; then
    echo "⏳ Disabling timer..."
    systemctl --user disable "${SERVICE_NAME}.timer"
fi

# ---- Remove unit files ----------------------------------------------------
for unit in "${SERVICE_NAME}.service" "${SERVICE_NAME}.timer"; do
    if [[ -f "${SYSTEMD_DIR}/${unit}" ]]; then
        rm -f "${SYSTEMD_DIR}/${unit}"
        echo "✅ Removed: ${SYSTEMD_DIR}/${unit}"
    else
        echo "ℹ️  Not found: ${SYSTEMD_DIR}/${unit}"
    fi
done

# ---- Reload daemon --------------------------------------------------------
systemctl --user daemon-reload

echo ""
echo "Done! The scheduled bot has been removed. 🏁"
