FROM ghcr.io/cirruslabs/flutter:stable

ARG API_BASE_URL=http://localhost:8000/api
ENV API_BASE_URL=${API_BASE_URL}

WORKDIR /app

COPY pubspec.yaml .
RUN flutter pub get

COPY . .
RUN flutter config --enable-web

EXPOSE 8080

CMD ["sh", "-c", "flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=API_BASE_URL=${API_BASE_URL}"]
