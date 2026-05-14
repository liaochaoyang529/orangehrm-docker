#!/bin/bash
#
# OrangeHRM Docker Compose 一键安装脚本
# 零侵入宿主机，完全隔离
#

set -euo pipefail

# ==================== 默认配置 ====================
SOURCE_DIR=""
DB_ROOT_PASS="$(openssl rand -base64 16 2>/dev/null || tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)"
DB_NAME="orangehrm"
WEB_PORT=8080
ADMIN_USER="Admin"
ADMIN_PASS="Ohrm@1423"
ADMIN_FIRSTNAME="OrangeHRM"
ADMIN_LASTNAME="Admin"
ADMIN_EMAIL="admin@example.com"
ORG_NAME="OrangeHRM"
ORG_COUNTRY="US"
DRY_RUN=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
OrangeHRM Docker Compose 安装脚本

用法: $0 [选项]

选项:
  --source-dir <路径>      OrangeHRM 源码目录 (必需)
  --web-port <端口>        映射到宿主机的端口 (默认: 8080)
  --db-root-pass <密码>    MariaDB root 密码 (默认随机生成)
  --admin-pass <密码>      管理员密码 (默认: Ohrm@1423)
  --admin-email <邮箱>     管理员邮箱 (默认: admin@example.com)
  --dry-run                模拟执行，不实际修改系统
  -h, --help               显示此帮助

示例:
  $0 --source-dir ./orangehrm-5.8.1 --web-port 8080
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source-dir)      SOURCE_DIR="$2"; shift 2 ;;
            --web-port)        WEB_PORT="$2"; shift 2 ;;
            --db-root-pass)    DB_ROOT_PASS="$2"; shift 2 ;;
            --admin-pass)      ADMIN_PASS="$2"; shift 2 ;;
            --admin-email)     ADMIN_EMAIL="$2"; shift 2 ;;
            --dry-run)         DRY_RUN=true; shift ;;
            -h|--help)         usage; exit 0 ;;
            *) log_error "未知参数: $1"; usage; exit 1 ;;
        esac
    done
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "未找到 Docker。请先安装 Docker:"
        log_error "  curl -fsSL https://get.docker.com | sh"
        return 1
    fi
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        log_error "未找到 Docker Compose。请先安装:"
        log_error "  apt-get install docker-compose-plugin"
        return 1
    fi
    log_ok "Docker 和 Docker Compose 已安装"
    return 0
}

check_source_dir() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        log_error "未指定 --source-dir"
        return 1
    fi
    if [[ ! -d "$dir" ]]; then
        log_error "源码目录不存在: $dir"
        return 1
    fi
    if [[ ! -f "$dir/src/composer.json" ]]; then
        log_error "目录 $dir 不是有效的 OrangeHRM 源码"
        return 1
    fi
    log_ok "源码目录验证通过: $dir"
    return 0
}

check_port() {
    local port="$1"
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        log_error "端口 ${port} 已被占用，请使用其他端口（如 8081、8090）"
        return 1
    fi
    log_ok "端口 ${port} 可用"
    return 0
}

run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] $*"
        return 0
    fi
    "$@"
}

docker_compose_cmd() {
    if docker compose version &>/dev/null; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

main() {
    parse_args "$@"

    log_info "OrangeHRM Docker Compose 安装脚本启动"

    check_docker || exit 1
    check_source_dir "$SOURCE_DIR" || exit 1
    check_port "$WEB_PORT" || exit 1

    # 导出环境变量给 docker-compose 使用
    export SOURCE_DIR
    export WEB_PORT
    export DB_ROOT_PASS
    export DB_NAME

    log_info "启动 Docker 容器..."
    run_cmd docker_compose_cmd down -v 2>/dev/null || true
    run_cmd docker_compose_cmd up -d --build

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 跳过容器内安装步骤"
        print_report
        exit 0
    fi

    log_info "等待数据库就绪..."
    local retries=0
    while ! docker_compose_cmd exec -T db mysqladmin ping --silent 2>/dev/null; do
        sleep 2
        retries=$((retries + 1))
        if [[ $retries -gt 30 ]]; then
            log_error "数据库启动超时"
            exit 1
        fi
    done
    log_ok "数据库已就绪"

    log_info "安装 PHP Composer 依赖..."
    docker_compose_cmd exec -T app bash -c "cd /var/www/html/src && composer install --no-dev --optimize-autoloader"
    log_ok "Composer 依赖安装完成"

    log_info "配置 OrangeHRM CLI 安装..."
    cat > "${SOURCE_DIR}/installer/cli_install_config.yaml" <<EOF
database:
  hostName: db
  hostPort: 3306
  databaseName: ${DB_NAME}
  privilegedDatabaseUser: root
  privilegedDatabasePassword: ${DB_ROOT_PASS}
  useSameDbUserForOrangeHRM: y
  orangehrmDatabaseUser: ~
  orangehrmDatabasePassword: ~
  isExistingDatabase: n
  enableDataEncryption: n

organization:
  name: ${ORG_NAME}
  country: ${ORG_COUNTRY}

admin:
  adminUserName: ${ADMIN_USER}
  adminPassword: ${ADMIN_PASS}
  adminEmployeeFirstName: ${ADMIN_FIRSTNAME}
  adminEmployeeLastName: ${ADMIN_LASTNAME}
  workEmail: ${ADMIN_EMAIL}
  contactNumber: ~
  registrationConsent: true

license:
  agree: y
EOF

    log_info "执行 OrangeHRM CLI 安装..."
    # MariaDB 会自动创建 MYSQL_DATABASE，导致 cli_install.php 的 createDatabase() 失败，先删除
    docker_compose_cmd exec -T db bash -c "mysql -uroot -p'${DB_ROOT_PASS}' -e 'DROP DATABASE IF EXISTS \`${DB_NAME}\`;'" >/dev/null 2>&1 || true
    docker_compose_cmd exec -T app bash -c "cd /var/www/html && php installer/cli_install.php"
    log_ok "OrangeHRM 安装完成"

    # 设置权限
    docker_compose_cmd exec -T app bash -c "chown -R www-data:www-data /var/www/html && chmod -R 755 /var/www/html"

    print_report
}

print_report() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}===============================================${NC}"
    echo -e "${GREEN}      OrangeHRM 安装成功！${NC}"
    echo -e "${GREEN}===============================================${NC}"
    echo ""
    echo "访问地址:"
    echo "  - 本机:     http://localhost:${WEB_PORT}"
    echo "  - 局域网:   http://${ip}:${WEB_PORT}"
    echo ""
    echo "管理员账号:"
    echo "  用户名: ${ADMIN_USER}"
    echo "  密码:   ${ADMIN_PASS}"
    echo "  邮箱:   ${ADMIN_EMAIL}"
    echo ""
    echo "数据库信息:"
    echo "  容器名: orangehrm-db"
    echo "  数据库: ${DB_NAME}"
    echo "  root密码: ${DB_ROOT_PASS}"
    echo ""
    echo "常用命令:"
    echo "  停止:    docker-compose down"
    echo "  启动:    docker-compose up -d"
    echo "  日志:    docker-compose logs -f app"
    echo "  进容器:  docker-compose exec app bash"
    echo ""
    echo -e "${YELLOW}提示: 首次登录后请立即修改默认管理员密码。${NC}"
    echo -e "${GREEN}===============================================${NC}"
}

main "$@"
