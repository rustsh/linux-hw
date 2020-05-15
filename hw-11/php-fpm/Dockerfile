FROM alpine:latest
RUN apk update && apk add --no-cache php7 php7-fpm && \
    ln -s /dev/stderr /var/log/php7/error.log && \
    sed -i 's/listen = 127.0.0.1:9000/listen = 9000/' /etc/php7/php-fpm.d/www.conf
CMD ["php-fpm7", "-F"]