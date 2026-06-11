#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

INTERVAL_SECONDS="${BLOG_SYNC_INTERVAL_SECONDS:-60}"
DEBOUNCE_SECONDS="${BLOG_SYNC_DEBOUNCE_SECONDS:-10}"
COMMIT_PREFIX="${BLOG_SYNC_COMMIT_PREFIX:-Update blog content}"
LOG_FILE="${BLOG_SYNC_LOG_FILE:-.auto-sync.log}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

ensure_repo_ready() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "当前目录不是 Git 仓库"
    exit 1
  fi

  if ! git remote get-url origin >/dev/null 2>&1; then
    log "未配置 origin 远程仓库"
    exit 1
  fi
}

has_changes() {
  [ -n "$(git status --porcelain)" ]
}

sync_once() {
  if ! has_changes; then
    return 0
  fi

  log "检测到本地文件变化，等待 ${DEBOUNCE_SECONDS}s 合并连续修改"
  sleep "$DEBOUNCE_SECONDS"

  if ! has_changes; then
    log "变化已消失，跳过同步"
    return 0
  fi

  git add -A

  if git diff --cached --quiet; then
    log "没有需要提交的暂存变化"
    return 0
  fi

  local message
  message="${COMMIT_PREFIX}: $(date '+%Y-%m-%d %H:%M:%S')"

  git commit -m "$message"
  git push
  log "已推送到 GitHub，GitHub Actions 将自动更新网站"
}

main() {
  ensure_repo_ready
  log "启动博客自动同步：每 ${INTERVAL_SECONDS}s 检查一次"

  while true; do
    sync_once || log "本轮同步失败，稍后重试"
    sleep "$INTERVAL_SECONDS"
  done
}

main "$@"
