FROM alpine:3.24

# Install packages
RUN apk --no-cache add \
  php85 \
  php85-fpm \
  php85-mysqli \
  php85-json \
  php85-openssl \
  php85-curl \
  php85-zlib \
  php85-xml \
  php85-phar \
  php85-intl \
  php85-dom \
  php85-xmlreader \
  php85-xmlwriter \
  php85-exif \
  php85-fileinfo \
  php85-sodium \
  php85-simplexml \
  php85-ctype \
  php85-mbstring \
  php85-zip \
  php85-iconv \
  php85-pecl-imagick \
  php85-session \
  php85-tokenizer \
  php85-gd \
  php85-pecl-redis \
  php85-soap \
  php85-pdo \
  php85-sqlite3 \
  php85-pecl-apcu \
  mariadb-client \
  nginx \
  supervisor \
  inotify-tools \
  curl \
  bash \
  less \
  tzdata \
  ca-certificates

# Create symlink so programs depending on `php` still function
# RUN ln -s /usr/bin/php85 /usr/bin/php

# Install vips extension
RUN apk add --no-cache vips \
    && apk add --no-cache --virtual .vips-build-deps \
        php85-dev build-base autoconf pkgconf vips-dev \
    && curl -fsSL https://pecl.php.net/get/vips-1.0.13.tgz \
        -o /tmp/vips.tgz \
    && mkdir /tmp/vips-src \
    && tar -xzf /tmp/vips.tgz -C /tmp/vips-src --strip-components=1 \
    && cd /tmp/vips-src \
    && phpize85 \
    && ./configure --with-php-config=/usr/bin/php-config85 \
    && make -j"$(getconf _NPROCESSORS_ONLN)" \
    && make install \
    && echo 'extension=vips.so' > /etc/php85/conf.d/50-vips.ini \
    && cd / \
    && rm -rf /tmp/vips-src /tmp/vips.tgz \
    && apk del .vips-build-deps \
    && php85 --ri vips

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php85/php-fpm.d/zzz_custom.conf
ENV FPM_MAX_CHILDREN=8
COPY config/php.ini /etc/php85/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir -p /usr/src/wordpress /var/log/nginx /var/log/php85 && chown -R nobody: /usr/src/wordpress /var/log/nginx /var/log/php85
WORKDIR /usr/src/wordpress

# Add WP CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x /usr/local/bin/wp

# Nginx restart watcher
COPY config/watch-wordpress-nginx.sh /usr/local/bin/watch-wordpress-nginx
RUN chmod +x /usr/local/bin/watch-wordpress-nginx

# Entrypoint to install plugins
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# healthcheck runs cron queue every 5 mintes - add disable_cron to wp-config
# plugins are loaded unless WP_CRON_SKIP_PLUGINS is set to true or 1
HEALTHCHECK --interval=300s --timeout=120s CMD curl -fsS http://localhost/ >/dev/null && \
  case "$WP_CRON_SKIP_PLUGINS" in true|TRUE|1) SKIP_PLUGINS=--skip-plugins ;; *) SKIP_PLUGINS= ;; esac && \
  su -s /bin/sh nobody -c "sleep $(tr -dc 0-9 </dev/urandom | head -c2) && wp cron event run --due-now --skip-themes $SKIP_PLUGINS --path=/usr/src/wordpress --quiet" || exit 1
