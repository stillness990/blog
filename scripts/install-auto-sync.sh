#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
BLOG_DIR="$(pwd)"
SERVICE_NAME="blog-auto-sync"
SERVICE_FILE="${HOME}/.config/systemd/user/${SERVICE_NAME}.service"
TIMER_FILE="${HOME}/.config/systemd/user/${SERVICE_NAME}.timer"

mkdir -p "${HOME}/.config/systemd/user"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Blog auto sync service - watch local changes and push to GitHub
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BLOG_DIR}/scripts/auto-sync.sh
WorkingDirectory=${BLOG_DIR}
Restart=on-failure
RestartSec=10
Environment=BLOG_SYNC_INTERVAL_SECONDS=60
Environment=BLOG_SYNC_DEBOUNCE_SECONDS=10

[Install]
WantedBy=default.target
EOF

cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Blog auto sync timer - runs service periodically

[Timer]
OnBootSec=30
OnUnitActiveSec=5m
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload

echo "安装完成。可用命令如下："
echo
echo "  手动启动一次："
echo "    systemctl --user start ${SERVICE_NAME}"
echo
echo "  查看运行状态："
echo "    systemctl --user status ${SERVICE_NAME}"
echo
echo "  开机自动运行（推荐）："
echo "    systemctl --user enable ${SERVICE_NAME}"
echo
echo "  一次性模式（无需 systemd）："
echo "    ${BLOG_DIR}/scripts/auto-sync.sh"