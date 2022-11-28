FROM alpine:3.17

# Install packages
RUN apk --no-cache add \
  php81 \
  php81-fpm \
  php81-mysqli \
  php81-json \
  php81-openssl \
  php81-curl \
  php81-zlib \
  php81-xml \
  php81-phar \
  php81-intl \
  php81-dom \
  php81-xmlreader \
  php81-xmlwriter \
  php81-exif \
  php81-fileinfo \
  php81-sodium \
  php81-simplexml \
  php81-ctype \
  php81-mbstring \
  php81-zip \
  php81-opcache \
  php81-iconv \
  php81-pecl-imagick \
  php81-pecl-vips \
  php81-session \
  php81-tokenizer \
  php81-gd \
  php81-pecl-redis \
  mysql-client \
  nginx \
  supervisor \
  curl \
  bash \
  less

# Create symlink so programs depending on `php` still function
RUN ln -s /usr/bin/php81 /usr/bin/php

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php81/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php81/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN mkdir -p /usr/src/wordpress && chown -R nobody: /usr/src/wordpress

WORKDIR /usr/src

# Add WP CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x /usr/local/bin/wp

# Entrypoint to install plugins
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# healthcheck runs cron queue every 5 mintes - add disable_cron to wp-config
HEALTHCHECK --interval=300s CMD curl --silent --fail http://127.0.0.1/wp-cron.php?doing_wp_cron