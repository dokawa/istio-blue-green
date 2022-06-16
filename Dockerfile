FROM nginx:1.16.0-alpine
COPY app /usr/share/nginx/html
EXPOSE 80
