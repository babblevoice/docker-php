FROM php:7.4.30-fpm-alpine3.15 as builder

# prepare to install dependencies, install and include extensions
# NB adds also -common, -fpm and -snmp plus equivalents for PHP 8
RUN apk upgrade --update ; \
    apk add --no-cache libpng-dev zlib-dev tzdata; \
    docker-php-ext-install -j$(nproc) gd opcache; \
    docker-php-source delete;

CMD [ "/usr/local/sbin/php-fpm", "-c", "/etc/php/php.ini", "-y", "/etc/php/php-fpm.conf" ]
