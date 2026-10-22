# PHP 7.4 is end-of-life, so no official image carries the fix for
# CVE-2026-109618 and CVE-2026-109619 (php2shell). This stage is the official
# 7.4.33 image with PHP recompiled from its own signed source plus the PHP
# security team's backport of the fix, with upstream's configure flags.
#
# The patch is php-src commit 712e60f9edfd03f0960fc4fc3c2c375f42b90aa2 (branch
# PHP-7.4-CVE-2026-109618-109619), exported with git format-patch. It changes
# inline code in Zend headers (HT_HASH_RESET, the zend_multiply.h overflow
# checks), so every extension is built on this stage, against those headers,
# rather than taken from Alpine's php7-* packages, built for Alpine's own PHP.
#
# This is a bridge until babble_web moves to PHP 8 (babble_web#1162).
FROM php:7.4.33-fpm-alpine3.15@sha256:6e48c96408fe0835a0f8bd736692721f222aeac4cff0de102780687a768eb55c AS php-patched

COPY patches/ /usr/src/patches/

RUN set -eux; \
    # Alpine 3.15's final packages, so the libraries PHP links against
    # (libcurl, OpenSSL, libxml2) and the tools using them stay in step.
    apk upgrade --no-cache; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS argon2-dev coreutils curl-dev \
        gnu-libiconv-dev libsodium-dev libxml2-dev linux-headers oniguruma-dev openssl-dev \
        readline-dev sqlite-dev patch; \
    rm -vf /usr/include/iconv.h; \
    ln -sfv /usr/include/gnu-libiconv/*.h /usr/include/; \
    export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"; \
    # The signed php-7.4.33.tar.xz, checked here rather than against the
    # base image's own PHP_SHA256.
    echo "924846abf93bc613815c55dd3f5809377813ac62a9ec4eb3778675b82a27b927 */usr/src/php.tar.xz" | sha256sum -c -; \
    docker-php-source extract; \
    cd /usr/src/php; \
    patch -p1 < /usr/src/patches/php-7.4-CVE-2026-109618-109619.patch; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure --build="$gnuArch" --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" --enable-option-checking=fatal \
        --with-mhash --with-pic --enable-ftp --enable-mbstring --enable-mysqlnd \
        --with-password-argon2 --with-sodium=shared --with-pdo-sqlite=/usr --with-sqlite3=/usr \
        --with-curl --with-iconv=/usr --with-openssl --with-readline --with-zlib --disable-phpdbg \
        --with-pear --disable-cgi --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data; \
    make -j "$(nproc)"; \
    find -type f -name '*.a' -delete; \
    # PEAR is plain PHP the base image already installed - don't install it over itself.
    sed -i '/^install_targets = /s/ install-pear//' Makefile; \
    make install; \
    find /usr/local -type f -perm '/0111' -exec sh -euxc 'strip --strip-all "$@" || :' -- '{}' +; \
    cd /; \
    docker-php-source delete; \
    rm -rf /usr/src/patches; \
    apk del --no-network .build-deps; \
    php --version

FROM php-patched AS builder

# Build the extensions php.ini loads, against the patched headers.
RUN apk update --no-cache; \
    apk add --no-cache libpng-dev zlib-dev icu-dev; \
    docker-php-ext-install -j$(nproc) bcmath calendar gd intl pdo_mysql sockets;

FROM php-patched AS app

RUN apk update --no-cache; \
    apk add --no-cache libpng icu-libs zlib tzdata sipp zip rrdtool; \
    mkdir -p /var/lib/php/session && chmod a+xw /var/lib/php/session; \
    mkdir -p /var/lib/php/wsdlcache && chmod a+xw /var/lib/php/wsdlcache;

# Composer runs on the patched PHP. Alpine's composer package would bring its
# own, unpatched PHP 8.0 with it.
COPY --from=composer:2.2.30@sha256:3d411d7de2b6e20e8869ddd13adefd218ba944f04af2875802ee269906181590 /usr/bin/composer /usr/bin/composer.phar
RUN printf '#!/bin/sh\nexec /usr/local/bin/php /usr/bin/composer.phar "$@"\n' > /usr/bin/composer; \
    chmod +x /usr/bin/composer;

# grab the built modules
COPY --from=builder /usr/local/lib/php/extensions/no-debug-non-zts-20190902/ /usr/lib/php7/modules/
COPY config/php.ini /etc/php/php.ini
COPY config/php-fpm.conf /etc/php/php-fpm.conf

# Fail the build if PHP, its extensions, php-fpm's config or composer don't
# start: CI builds arm64 but never runs it otherwise.
RUN set -eux; \
    php -c /etc/php/php.ini -r 'foreach (["bcmath", "calendar", "gd", "intl", "pdo_mysql", "sockets", "sodium"] as $e) if (!extension_loaded($e)) { fwrite(STDERR, "missing $e\n"); exit(1); }'; \
    php-fpm -c /etc/php/php.ini -y /etc/php/php-fpm.conf -t; \
    rm -f /var/log/php-fpm.log; \
    composer --version

WORKDIR /usr/share/nginx/html

CMD [ "/usr/local/sbin/php-fpm", "-c", "/etc/php/php.ini", "-y", "/etc/php/php-fpm.conf" ]
