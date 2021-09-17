FROM alpine:3.14

# Install packages
RUN apk --no-cache add \
  php8 \
  php8-fpm \
  php8-mysqli \
  php8-json \
  php8-openssl \
  php8-curl \
  php8-zlib \
  php8-xml \
  php8-phar \
  php8-intl \
  php8-dom \
  php8-xmlreader \
  php8-xmlwriter \
  php8-exif \
  php8-fileinfo \
  php8-sodium \
  php8-gd \
  php8-simplexml \
  php8-ctype \
  php8-mbstring \
  php8-zip \
  php8-opcache \
  php8-iconv \
  php8-pecl-imagick \
  php8-session \
  php8-pecl-redis \
  nginx \
  supervisor \
  curl \
  bash \
  less \
  redis

# Create symlink so programs depending on `php` still function
RUN ln -s /usr/bin/php8 /usr/bin/php

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php8/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php8/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# wp-content volume
#VOLUME /var/www/wp-content
#WORKDIR /var/www/wp-content
#RUN chown -R nobody.nobody /var/www

# WordPress
# ENV WORDPRESS_VERSION 5.7.2
# ENV WORDPRESS_SHA1 c97c037d942e974eb8524213a505268033aff6c8

# RUN mkdir -p /usr/src

# Upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN mkdir -p /usr/src/wordpress && chown -R nobody.nobody /usr/src/wordpress

# Add WP CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# WP config
# COPY wp-config.php /usr/src/wordpress
# RUN chown nobody.nobody /usr/src/wordpress/wp-config.php && chmod 640 /usr/src/wordpress/wp-config.php

# Append WP secrets
# COPY wp-secrets.php /usr/src/wordpress
# RUN chown nobody.nobody /usr/src/wordpress/wp-secrets.php && chmod 640 /usr/src/wordpress/wp-secrets.php

# Entrypoint to copy wp-content
# COPY entrypoint.sh /entrypoint.sh
# ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/wp-login.php
