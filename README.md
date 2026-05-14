# OrangeHRM Docker Compose 开发环境

## 方案特点

| 特性 | 说明 |
|------|------|
| **零侵入** | 不修改宿主机任何系统配置 |
| **完全隔离** | Apache/PHP/MySQL 全部运行在容器内 |
| **支持二次开发** | 源码挂载到宿主机，IDE 直接修改 |
| **一键启停** | `docker-compose up -d` 启动，`docker-compose down` 停止 |
| **数据持久化** | 数据库数据保存在 Docker Volume 中 |
| **端口自定义** | 默认使用 8080 端口，避免与宿主机 80 端口冲突 |

## 二次开发说明

### 修改 PHP 后端代码
直接在本地的源码目录用 IDE（VSCode/PhpStorm）修改 PHP 文件，保存后立即生效，无需重启容器。

### 修改前端代码
OrangeHRM 前端源码位于 `installer/client/`（Vue 3 项目）。

**方式1：在宿主机构建（推荐）**
```bash
cd installer/client
yarn install
yarn build
# 构建产物会自动同步到容器
```

**方式2：在容器内构建**
```bash
docker-compose exec app bash
cd installer/client
yarn build
```

### 安装新的 Composer 包
```bash
docker-compose exec app bash
cd src
composer require xxxx
```

## 目录结构

```
orangehrm-docker/
├── docker-compose.yml      # 服务定义
├── Dockerfile              # 应用镜像构建
├── install.sh              # 一键安装脚本
├── uninstall.sh            # 完全卸载脚本
└── README.md               # 本文件
```

## 使用方式

### 前置要求
宿主机只需安装 Docker 和 Docker Compose：
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
```

### 安装步骤

1. 将 OrangeHRM 源码解压到任意目录，例如 `/data/orangehrm-5.8.1`

2. 运行安装脚本：
```bash
./install.sh --source-dir /data/orangehrm-5.8.1
```

3. 访问系统：
```
http://localhost:8080
```

### 停止/启动
```bash
# 停止
docker-compose down

# 启动
docker-compose up -d

# 查看日志
docker-compose logs -f app
```

### 完全卸载（数据也会删除）
```bash
./uninstall.sh
```

## 技术细节

- **App 容器**：基于 `php:8.1-apache`，安装了所有必需的 PHP 扩展和 Composer
- **DB 容器**：基于 `mariadb:10.6`
- **网络**：Docker 内部网络隔离，数据库不暴露到宿主机
- **源码挂载**：宿主机源码目录直接挂载到容器 `/var/www/html`，修改实时同步
- **数据卷**：数据库数据保存在 Docker Volume 中，容器重建不丢失
