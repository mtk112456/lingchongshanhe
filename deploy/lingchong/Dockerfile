# 灵宠山河 API 镜像：PHP 8.4 + Apache + pdo_mysql
# 构建上下文是仓库根目录：
#   docker build -f deploy/lingchong/Dockerfile -t lingchong-api:local .
# 生产配置（display_errors / expose_php）已在本文件关闭，不依赖宿主机 php.ini。

FROM php:8.4-apache

ENV TZ=Asia/Shanghai \
    SLICE_CONFIG=/var/www/html/config.docker.php

# pdo_mysql 是唯一运行期扩展；curl 只用于容器 healthcheck 和排障。
# 容器内统一监听 8080，cloudflared 回源 http://api:8080。
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl; \
    rm -rf /var/lib/apt/lists/*; \
    docker-php-ext-install -j"$(nproc)" pdo_mysql; \
    a2enmod rewrite headers; \
    sed -ri 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf; \
    sed -ri 's#<VirtualHost \*:80>#<VirtualHost *:8080>#' /etc/apache2/sites-available/000-default.conf

# 文档根只指向 public/，server/slice 其余源码和 SQL 不对外暴露。
RUN set -eux; \
    sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf; \
    printf '%s\n' \
      '<Directory /var/www/html/public>' \
      '    Options -Indexes +FollowSymLinks' \
      '    AllowOverride All' \
      '    Require all granted' \
      '</Directory>' \
      > /etc/apache2/conf-available/lingchong.conf; \
    a2enconf lingchong; \
    printf '%s\n' \
      'ServerTokens Prod' \
      'ServerSignature Off' \
      'TraceEnable Off' \
      > /etc/apache2/conf-available/lingchong-hardening.conf; \
    a2enconf lingchong-hardening

# 生产 PHP 配置：不回显错误、不暴露版本、错误只进 stderr。
RUN set -eux; \
    { \
      echo 'expose_php = Off'; \
      echo 'display_errors = Off'; \
      echo 'display_startup_errors = Off'; \
      echo 'log_errors = On'; \
      echo 'error_log = /dev/stderr'; \
      echo 'error_reporting = E_ALL & ~E_DEPRECATED'; \
      echo 'memory_limit = 256M'; \
      echo 'max_execution_time = 60'; \
      echo 'post_max_size = 8M'; \
      echo 'upload_max_filesize = 8M'; \
      echo 'session.cookie_httponly = 1'; \
      echo 'date.timezone = Asia/Shanghai'; \
    } > /usr/local/etc/php/conf.d/zz-lingchong.ini

WORKDIR /var/www/html

# 只复制运行所需文件；config.local.php / config.trial.php 等本机凭据不会进镜像。
COPY server/slice/bootstrap.php ./
COPY server/slice/src/ ./src/
COPY server/slice/public/ ./public/
COPY server/slice/scripts/ ./scripts/
COPY server/slice/migrations/ ./migrations/
COPY server/slice/schema.sql server/slice/legacy_schema.sql server/slice/seed.sql server/slice/legacy_seed.sql server/slice/seed_map12.sql ./
COPY deploy/lingchong/config.docker.php ./config.docker.php

RUN set -eux; \
    mkdir -p logs; \
    chown -R www-data:www-data /var/www/html; \
    chmod 775 logs

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/api/health || exit 1
