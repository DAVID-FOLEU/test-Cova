# Étape 1 : Compilation de l'application Flutter Web
FROM ghcr.io/flutter/flutter:3.22.0 AS builder
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# Étape 2 : Service des fichiers statiques Web avec Nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]