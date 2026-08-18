FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=""

WORKDIR /app

COPY pubspec.yaml .
RUN flutter pub get

COPY . .
RUN flutter config --enable-web \
    && flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
