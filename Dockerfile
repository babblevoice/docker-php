FROM php:7.4.30-fpm-alpine3.15 as builder

# Build the GD extension - we install when there are pre-built ones available.
RUN apk upgrade --update ; \
    apk add --no-cache libpng-dev zlib-dev; \
    docker-php-ext-install -j$(nproc) gd;

FROM php:7.4.30-fpm-alpine3.15 as app

RUN apk upgrade --update ; \
  apk add --no-cache libpng zlib tzdata composer php7-opcache php7-simplexml php7-pdo_mysql php7-bcmath php7-calendar sipp zip rrdtool

# grab the built modules
COPY --from=builder /usr/local/lib/php/extensions/no-debug-non-zts-20190902/ /usr/lib/php7/modules/
COPY config/php.ini /etc/php/php.ini
COPY config/php-fpm.conf /etc/php/php-fpm.conf

WORKDIR /usr/share/nginx/html

CMD [ "/usr/local/sbin/php-fpm", "-c", "/etc/php/php.ini", "-y", "/etc/php/php-fpm.conf" ]
