#! /bin/bash

# terminate on errors
set -e

# install wordpress if necessary
CONFIG=/usr/src/wordpress/wp-config.php
SAMPLE=/usr/src/wordpress/wp-config-sample.php
if [ "$(ls -A /usr/src/wordpress)" ]; then
	echo "Wordpress folder is not empty. Skipping install..."
else
	echo "Wordpress files do not exist. Installing..."
	if [[ ! -f "$SAMPLE" ]]; then
		# download & extract wordpress
		wget -q https://wordpress.org/latest.tar.gz \
			&& tar -xzkf latest.tar.gz -C /usr/src/ \
			&& rm latest.tar.gz \
			&& chown -R nobody: /usr/src/wordpress
	fi
	echo "*** Please restart container after Wordpress setup ***"
	exec "$@"
fi

# exit if no wp-config.php
if [[ ! -f "$CONFIG" ]]; then
	echo "*** Config file not found. Please restart after installing Wordpress. ***"
	exec "$@"
fi
# disable cron - handled by healthcheck
cd /usr/src/wordpress && wp config set DISABLE_WP_CRON true --raw

# redis options
if [ -z "$WP_REDIS_HOST" ]; then
  echo "To use redis, please define WP_REDIS_HOST"
else
  cd /usr/src/wordpress && wp config set WP_REDIS_HOST "$WP_REDIS_HOST"
  cd /usr/src/wordpress && wp config set WP_REDIS_TIMEOUT 1 --raw
  cd /usr/src/wordpress && wp config set WP_REDIS_READ_TIMEOUT 1 --raw
fi
if [ -z "$WP_REDIS_DATABASE" ]; then
  echo "To specify redis database, please define WP_REDIS_DATABASE"
else
  cd /usr/src/wordpress && wp config set WP_REDIS_DATABASE "$WP_REDIS_DATABASE" --raw
fi

# install recommended plugins
if [ "$INSTALL_PLUGINS" == "true" ] ; then
	if [ ! "$(ls -A "/usr/src/wordpress/wp-content/plugins/vips-image-editor" 2>/dev/null)" ]; then
		echo 'Adding plugin: vips-image-editor'
		cd /usr/src/wordpress && wp plugin install --activate https://github.com/henrygd/vips-image-editor/releases/latest/download/vips-image-editor.zip
	fi

	if [ ! "$(ls -A "/usr/src/wordpress/wp-content/plugins/redis-cache" 2>/dev/null)" ]; then
		echo 'Adding plugin: redis-cache'
		cd /usr/src/wordpress && wp plugin install --activate redis-cache
	fi

	if [ ! "$(ls -A "/usr/src/wordpress/wp-content/plugins/disable-media-pages" 2>/dev/null)" ]; then
		echo 'Adding plugin: disable-media-pages'
		cd /usr/src/wordpress && wp plugin install --activate disable-media-pages
	fi
else
	echo "Not installing recommended plugins..."
fi

# install additional plugins
for PLUGIN in $ADDITIONAL_PLUGINS; do
	echo "Adding plugin: $PLUGIN"
	if [ ! "$(ls -A "/usr/src/wordpress/wp-content/plugins/$PLUGIN" 2>/dev/null)" ]; then
		cd /usr/src/wordpress && wp plugin install --activate $PLUGIN
	fi
done

# handle cron
if [ -z "$CRON" ]; then
  echo "No cron commands specified..."
else
	# add commands
	echo "$CRON" > /tmp/newcron
	crontab /tmp/newcron
  rm /tmp/newcron

	echo "Starting cron daemon..."
	/usr/sbin/crond
fi

# make sure plugins have correct permissions
chown -R nobody: /usr/src/wordpress/wp-content/plugins

exec "$@"