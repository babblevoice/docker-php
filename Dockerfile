FROM php:7.4.30-fpm-alpine3.15 as builder

# Build the GD extension - we install when there are pre-built ones available.
RUN apk update --no-cache; \
    apk add --no-cache libpng-dev zlib-dev; \
    docker-php-ext-install -j$(nproc) gd sockets;

FROM php:7.4.30-fpm-alpine3.15 as app

RUN apk update --no-cache; \
    apk add --no-cache libpng zlib tzdata composer php7-opcache \
        php7-simplexml php7-xml php7-intl php7-dom php7-xmlreader php7-ctype php7-session \
        php7-pdo_mysql php7-bcmath php7-calendar sipp zip rrdtool; \
    mkdir -p /var/lib/php/session && chmod a+xw /var/lib/php/session; \
    mkdir -p /var/lib/php/wsdlcache && chmod a+xw /var/lib/php/wsdlcache;

# grab the built modules
COPY --from=builder /usr/local/lib/php/extensions/no-debug-non-zts-20190902/ /usr/lib/php7/modules/
COPY config/php.ini /etc/php/php.ini
COPY config/php-fpm.conf /etc/php/php-fpm.conf

WORKDIR /usr/share/nginx/html

CMD [ "/usr/local/sbin/php-fpm", "-c", "/etc/php/php.ini", "-y", "/etc/php/php-fpm.conf" ]
