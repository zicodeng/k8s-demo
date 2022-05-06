FROM nginx
LABEL maintainer="Zico Deng"

COPY website /website
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

