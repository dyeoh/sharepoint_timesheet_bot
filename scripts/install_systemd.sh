#!/bin/bash
# ===========================================================================
# install_systemd.sh — Install a systemd user timer for scheduled runs (Linux)
# ===========================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="sharepoint-timesheet-bot"

echo "📦 Installing SharePoint Timesheet Bot systemd timer..."
echo ""

# ---- Ensure wrapper script is executable ----------------------------------
chmod +x "${PROJECT_DIR}/scripts/run_timesheet.sh"

# ---- Ensure logs directory exists -----------------------------------------
mkdir -p "${PROJECT_DIR}/logs"

# ---- Ensure systemd user directory exists ---------------------------------
mkdir -p "$SYSTEMD_DIR"

# ---- Write .service file --------------------------------------------------
cat > "${SYSTEMD_DIR}/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=SharePoint Timesheet Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${PROJECT_DIR}
ExecStart=${PROJECT_DIR}/scripts/run_timesheet.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

echo "✅ Service file written: ${SYSTEMD_DIR}/${SERVICE_NAME}.service"

# ---- Write .timer file (every Friday at 09:00) ----------------------------
cat > "${SYSTEMD_DIR}/${SERVICE_NAME}.timer" <<EOF
[Unit]
Description=Run SharePoint Timesheet Bot every Friday at 9 AM

[Timer]
OnCalendar=Fri *-*-* 09:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "✅ Timer file written: ${SYSTEMD_DIR}/${SERVICE_NAME}.timer"

# ---- Reload and enable ----------------------------------------------------
systemctl --user daemon-reload
systemctl --user enable --now "${SERVICE_NAME}.timer"

echo ""
echo "ℹ️  Schedule: Every Friday at 09:00"
echo "ℹ️  Logs:     ${PROJECT_DIR}/logs/"
echo ""
echo "📋 Useful commands:"
echo "   Check timer:    systemctl --user list-timers"
echo "   Run now:        systemctl --user start ${SERVICE_NAME}.service"
echo "   Disable:        systemctl --user disable ${SERVICE_NAME}.timer"
echo "   View logs:      journalctl --user -u ${SERVICE_NAME}.service -f"
echo ""
echo "Done! The bot will run automatically every Friday at 9 AM. 🎉"
