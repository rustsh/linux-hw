FROM alpine:latest
RUN apk update && apk add --no-cache nginx && \
    ln -s /dev/stdout /var/log/nginx/access.log && \ 
    ln -s /dev/stderr /var/log/nginx/error.log && \
    mkdir -p /run/nginx
CMD ["nginx", "-g", "daemon off;"]