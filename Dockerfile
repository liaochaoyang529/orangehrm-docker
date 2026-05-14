FROM php:8.1-apache

LABEL maintainer="OrangeHRM Docker Dev"

# 安装系统依赖和 PHP 扩展
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libldap2-dev \
    libcurl4-openssl-dev \
    unzip \
    git \
    libicu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        mbstring \
        curl \
        xml \
        dom \
        simplexml \
        ldap \
        intl \
        opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 启用 Apache rewrite 模块
RUN a2enmod rewrite

# 安装 Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 设置工作目录
WORKDIR /var/www/html

# 开放 80 端口
EXPOSE 80

# 启动 Apache
CMD ["apache2-foreground"]
