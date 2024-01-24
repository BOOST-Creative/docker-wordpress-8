FROM alpine:3.19

# Install packages
RUN apk --no-cache add \
  php82 \
  php82-fpm \
  php82-mysqli \
  php82-json \
  php82-openssl \
  php82-curl \
  php82-zlib \
  php82-xml \
  php82-phar \
  php82-intl \
  php82-dom \
  php82-xmlreader \
  php82-xmlwriter \
  php82-exif \
  php82-fileinfo \
  php82-sodium \
  php82-simplexml \
  php82-ctype \
  php82-mbstring \
  php82-zip \
  php82-opcache \
  php82-iconv \
  php82-pecl-imagick \
  php82-pecl-vips \
  php82-session \
  php82-tokenizer \
  php82-gd \
  php82-pecl-redis \
  php82-soap \
  php82-pdo \
  mysql-client \
  nginx \
  supervisor \
  curl \
  bash \
  less \
  tzdata

# Create symlink so programs depending on `php` still function
# RUN ln -s /usr/bin/php82 /usr/bin/php

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php82/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php82/conf.d/zzz_custom.ini

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
HEALTHCHECK --interval=300s CMD su -s /bin/sh nobody -c "cd /usr/src/wordpress/ && wp cron event run --due-now --skip-themes --skip-plugins || exit 1"