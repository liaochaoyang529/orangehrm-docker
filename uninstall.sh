#!/bin/bash
#
# OrangeHRM Docker Compose 卸载脚本
# 完全清理所有容器、数据卷和网络
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo -e "${YELLOW}警告: 此操作将删除 OrangeHRM 容器及其数据库数据！${NC}"
read -rp "是否继续卸载? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "已取消卸载"
    exit 0
fi

docker_compose_cmd() {
    if docker compose version &>/dev/null; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

log_info "停止并删除容器..."
docker_compose_cmd down -v 2>/dev/null || true

log_info "删除构建的镜像..."
docker rmi orangehrm-docker-app 2>/dev/null || true

log_ok "卸载完成。OrangeHRM 已从系统中完全移除。"
