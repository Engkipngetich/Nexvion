FROM nginx:alpine
RUN apk update && apk upgrade --no-cache

WORKDIR /usr/share/nginx/html

COPY index.html products.html payment.html ./
COPY style.css products.css payment.css script.js payment.js logo.png ./

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
