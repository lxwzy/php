#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:jessie

# persistent / runtime deps
ENV PHPIZE_DEPS \
                autoconf \
                dpkg-dev \
                file \
                g++ \
                gcc \
                libc-dev \
                libpcre3-dev \
                make \
                pkg-config \
                re2c
RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak

COPY sources.list /etc/apt/sources.list

RUN apt-get update
RUN echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
RUN echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections
RUN apt-get install -y mysql-server
RUN service mysql start
RUN apt-get install -y \
                $PHPIZE_DEPS \
                ca-certificates \
                curl \
                libedit2 \
                libsqlite3-0 \
                libxml2 \
                xz-utils \
                libmysqlclient-dev \
        --no-install-recommends && rm -r /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

##<autogenerated>##
ENV PHP_EXTRA_CONFIGURE_ARGS --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data
##</autogenerated>##

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ENV GPG_KEYS 0BD78B5F97500D450838F95DFE857D9A90D90EC1 6E4F6AB321FDC07F2C332E3AC2BF0BC433CFC8B3

ENV PHP_VERSION 5.6.31
ENV PHP_URL="http://cn2.php.net/get/php-5.6.31.tar.xz/from/this/mirror" PHP_ASC_URL="http://cn2.php.net/get/php-5.6.31.tar.xz.asc/from/this/mirror"
ENV PHP_SHA256="c464af61240a9b7729fabe0314cdbdd5a000a4f0c9bd201f89f8628732fe4ae4" PHP_MD5=""

RUN set -xe; \
        \
        fetchDeps=' \
                wget \
        '; \
        if ! command -v gpg > /dev/null; then \
                fetchDeps="$fetchDeps \
                        dirmngr \
                        gnupg2 \
                "; \
        fi; \
        apt-get update; \
        apt-get install -y --no-install-recommends $fetchDeps; \
        rm -rf /var/lib/apt/lists/*; \
        \
        mkdir -p /usr/src; \
        cd /usr/src; \
        \
        wget -O php.tar.xz "$PHP_URL"; \
        \
        if [ -n "$PHP_SHA256" ]; then \
                echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
        fi; \
        if [ -n "$PHP_MD5" ]; then \
                echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
        fi; \
        \
        if [ -n "$PHP_ASC_URL" ]; then \
                wget -O php.tar.xz.asc "$PHP_ASC_URL"; \
                export GNUPGHOME="$(mktemp -d)"; \
                for key in $GPG_KEYS; do \
                        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
                done; \
                gpg --batch --verify php.tar.xz.asc php.tar.xz; \
                rm -rf "$GNUPGHOME"; \
        fi; \
        \
        apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps

COPY docker-php-source /usr/local/bin/

RUN set -xe \
        && buildDeps=" \
                $PHP_EXTRA_BUILD_DEPS \
                libcurl4-openssl-dev \
                libedit-dev \
                libsqlite3-dev \
                libssl-dev \
                libxml2-dev \
                zlib1g-dev \
        " \
        && apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
        \
        && export CFLAGS="$PHP_CFLAGS" \
                CPPFLAGS="$PHP_CPPFLAGS" \
                LDFLAGS="$PHP_LDFLAGS" \
        && docker-php-source extract \
        && cd /usr/src/php \
        && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
        && debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)" \
# https://bugs.php.net/bug.php?id=74125
        && if [ ! -d /usr/include/curl ]; then \
                ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
        fi \
        && ./configure \
                --build="$gnuArch" \
                --with-config-file-path="$PHP_INI_DIR" \
                --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
                \
                --disable-cgi \
                \
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
                --enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
                --enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
                --enable-mysqlnd \
                \
                --with-curl \
                --with-libedit \
                --with-openssl \
                --with-zlib \
                --with-mysql="/usr/"\
                \
# bundled pcre is too old for s390x (which isn't exactly a good sign)
# /usr/src/php/ext/pcre/pcrelib/pcre_jit_compile.c:65:2: error: #error Unsupported architecture
                --with-pcre-regex=/usr \
                --with-libdir="lib/$debMultiarch" \
                \
                $PHP_EXTRA_CONFIGURE_ARGS \
        && make -j "$(nproc)" \
        && make install \
        && { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
        && make clean \
        && cd / \
        && docker-php-source delete \
        \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $buildDeps \
        \
# https://github.com/docker-library/php/issues/443
        && pecl update-channels \
        && rm -rf /tmp/pear ~/.pearrc

COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

ENTRYPOINT ["docker-php-entrypoint"]
##<autogenerated>##
WORKDIR /var/www/html

RUN set -ex \
        && cd /usr/local/etc \
        && if [ -d php-fpm.d ]; then \
                # for some reason, upstream's php-fpm.conf.default has "include=NONE/etc/php-fpm.d/*.conf"
                sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
                cp php-fpm.d/www.conf.default php-fpm.d/www.conf; \
        else \
                # PHP 5.x doesn't use "include=" by default, so we'll create our own simple config that mimics PHP 7+ for consistency
                mkdir php-fpm.d; \
                cp php-fpm.conf.default php-fpm.d/www.conf; \
                { \
                        echo '[global]'; \
                        echo 'include=etc/php-fpm.d/*.conf'; \
                } | tee php-fpm.conf; \
        fi \
        && { \
                echo '[global]'; \
                echo 'error_log = /proc/self/fd/2'; \
                echo; \
                echo '[www]'; \
                echo '; if we send this to /proc/self/fd/1, it never appears'; \
                echo 'access.log = /proc/self/fd/2'; \
                echo; \
                echo 'clear_env = no'; \
                echo; \
                echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
                echo 'catch_workers_output = yes'; \
        } | tee php-fpm.d/docker.conf \
        && { \
                echo '[global]'; \
                echo 'daemonize = no'; \
                echo; \
                echo '[www]'; \
                echo 'listen = [::]:9000'; \
        } | tee php-fpm.d/zz-docker.conf

RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng12-dev \
    && docker-php-ext-install -j$(nproc) iconv mcrypt \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install zip \
    && docker-php-ext-install bcmath \
    && docker-php-ext-install calendar \
    && docker-php-ext-install sockets \
    &&  pecl install redis-3.1.0 \
    && pecl install xdebug-2.5.0 \
    && docker-php-ext-enable redis xdebug \
    && apt-get install -y libmemcached-dev zlib1g-dev \
    && pecl install memcached-2.2.0 \
    && docker-php-ext-enable memcached \
    && apt-get update && apt-get install -y unixodbc-dev \
    && docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr/ \
    && docker-php-ext-install pdo_odbc


EXPOSE 9000
CMD ["php-fpm"]
##</autogenerated>##
