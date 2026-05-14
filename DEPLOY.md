# OrangeHRM Docker 部署指南

本文档介绍如何将二次开发后的 OrangeHRM 打包成独立 Docker 镜像并部署。

---

## 一、前置条件

- 已完成二次开发（PHP / Vue 前端均已修改并构建）
- 当前在 `orangehrm-docker` 目录下操作

---

## 二、构建部署镜像

### 1. 创建 .dockerignore（排除不需要打包的文件）

在源码目录创建 `.dockerignore`：

```bash
cat > /home/orangehrm-5.8.1/orangehrm-5.8.1/.dockerignore << 'EOF'
node_modules
.git
*.Zone.Identifier
.yarn/cache
src/vendor
EOF
```

### 2. 构建镜像

```bash
docker build \
  -f /home/orangehrm-docker/Dockerfile.deploy \
  -t orangehrm-deploy:latest \
  /home/orangehrm-5.8.1/orangehrm-5.8.1/
```

构建完成后查看镜像：

```bash
docker images | grep orangehrm-deploy
```

---

## 三、本地测试部署镜像

### 方式 A：使用现有数据库（快速测试）

如果你已有开发环境的数据库在运行：

```bash
# 停止开发模式的 app 容器
cd /home/orangehrm-docker
docker compose stop app

# 用部署镜像启动新容器（复用现有数据库网络）
docker run -d \
  --name orangehrm-app \
  --network orangehrm-docker_orangehrm-net \
  -p 8080:80 \
  -e APACHE_DOCUMENT_ROOT=/var/www/html/web \
  --restart unless-stopped \
  orangehrm-deploy:latest

# 测试访问
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
# 预期返回：302（重定向，正常）

# 测试完成后，切回开发模式
docker stop orangehrm-app && docker rm orangehrm-app
docker compose up -d app
```

### 方式 B：全新部署（生产环境推荐）

使用 `docker-compose.deploy.yml` 一键启动完整环境（含数据库）：

```bash
cd /home/orangehrm-docker
docker compose -f docker-compose.deploy.yml up -d
```

---

## 四、推送到镜像仓库

### 1. 登录 Docker Hub

```bash
docker login
```

### 2. 给镜像打标签

将 `liaochaoyang529` 替换为你的 Docker Hub 用户名：

```bash
docker tag orangehrm-deploy:latest liaochaoyang529/orangehrm:5.8.1-custom
docker tag orangehrm-deploy:latest liaochaoyang529/orangehrm:latest
```

### 3. 推送镜像

```bash
docker push liaochaoyang529/orangehrm:5.8.1-custom
docker push liaochaoyang529/orangehrm:latest
```

---

## 五、别人如何部署你的镜像

### 单容器运行（需外部数据库）

```bash
# 先启动 MariaDB
docker run -d \
  --name orangehrm-db \
  -e MYSQL_ROOT_PASSWORD=orangehrm_root \
  -e MYSQL_DATABASE=orangehrm \
  -v orangehrm-db-data:/var/lib/mysql \
  mariadb:10.6

# 再启动 OrangeHRM
docker run -d \
  --name orangehrm-app \
  --link orangehrm-db:db \
  -p 8080:80 \
  -e APACHE_DOCUMENT_ROOT=/var/www/html/web \
  --restart unless-stopped \
  liaochaoyang529/orangehrm:latest
```

### 使用 Docker Compose（推荐）

创建 `docker-compose.yml`：

```yaml
services:
  app:
    image: liaochaoyang529/orangehrm:latest
    container_name: orangehrm-app
    ports:
      - "8080:80"
    environment:
      - APACHE_DOCUMENT_ROOT=/var/www/html/web
    depends_on:
      - db
    networks:
      - orangehrm-net
    restart: unless-stopped

  db:
    image: mariadb:10.6
    container_name: orangehrm-db
    environment:
      MYSQL_ROOT_PASSWORD: orangehrm_root
      MYSQL_DATABASE: orangehrm
    volumes:
      - orangehrm-db-data:/var/lib/mysql
    networks:
      - orangehrm-net
    restart: unless-stopped

volumes:
  orangehrm-db-data:

networks:
  orangehrm-net:
    driver: bridge
```

启动：

```bash
docker compose up -d
```

---

## 六、开发模式 vs 部署模式

| 对比项 | 开发模式 | 部署模式 |
|--------|----------|----------|
| **用途** | 本地二次开发 | 发布部署 |
| **源码位置** | 宿主机挂载（实时同步） | 打包在镜像内 |
| **修改生效** | 保存即生效（前端需 build） | 需重新构建镜像 |
| **启动命令** | `docker compose up -d` | `docker run` 或 `docker compose up -d` |
| **依赖文件** | `Dockerfile` + 源码目录 | `orangehrm-deploy` 镜像 |

---

## 七、常见问题

### Q1: 构建时超时或很慢？
确保源码目录已创建 `.dockerignore`，排除 `node_modules` 和 `.git` 等大量文件。

### Q2: 部署后数据库连接失败？
检查 `lib/confs/Conf.php` 中的数据库配置是否与容器网络环境匹配：
- 若使用 `docker run --link`，主机名应为 `db`
- 若使用 `docker compose`，主机名应为服务名 `db`

### Q3: 如何更新部署镜像？
修改源码 → 重新构建 → 重新打标签 → 重新推送：

```bash
docker build -f Dockerfile.deploy -t orangehrm-deploy:latest /home/orangehrm-5.8.1/orangehrm-5.8.1/
docker tag orangehrm-deploy:latest liaochaoyang529/orangehrm:latest
docker push liaochaoyang529/orangehrm:latest
```
