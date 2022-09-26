FROM php:7.4.30-fpm-alpine3.15 as builder

# prepare to install dependencies, install and include extensions
# NB adds also -common, -fpm and -snmp plus equivalents for PHP 8
# List of extensions at: https://github.com/mlocati/docker-php-extension-installer
RUN apk upgrade --update ; \
    apk add --no-cache libpng-dev zlib-dev tzdata; \
    docker-php-ext-install -j$(nproc) gd opcache pdo_mysql bcmath calendar;

FROM php:7.4.30-fpm-alpine3.15 as app

RUN apk upgrade --update ; \
  apk add --no-cache libpng zlib tzdata;

# grab the built modules
COPY --from=builder /usr/local/lib/php/extensions/no-debug-non-zts-20190902/ /usr/local/lib/php/extensions/no-debug-non-zts-20190902/
COPY config/php.ini /etc/php/php.ini
COPY config/php-fpm.conf /etc/php/php-fpm.conf

CMD [ "/usr/local/sbin/php-fpm", "-c", "/etc/php/php.ini", "-y", "/etc/php/php-fpm.conf" ]
