FROM node:20-alpine AS front-build

COPY ./front /src

WORKDIR /src

RUN npm ci \
    && npx @angular/cli build --optimization

FROM eclipse-temurin:17-jdk-jammy AS back-build

COPY ./back /src

WORKDIR /src

RUN apt-get update \
    && apt-get install --no-install-recommends -y dos2unix \
    && dos2unix gradlew \
    && chmod +x gradlew \
    && ./gradlew build \
    && apt-get purge -y dos2unix \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM caddy:2.8-alpine AS front

COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY misc/docker/Caddyfile /app/Caddyfile

WORKDIR /app

EXPOSE 80

CMD ["caddy", "run", "--config", "/app/Caddyfile", "--adapter", "caddyfile"]

FROM eclipse-temurin:17-jre-jammy AS back

COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm-0.0.1-SNAPSHOT.jar

RUN apt-get update \
    && apt-get install --no-install-recommends -y passwd wget \
    && useradd --system --create-home appuser \
    && chown -R appuser:appuser /app \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
USER appuser

EXPOSE 8080

CMD ["java", "-jar", "/app/back/microcrm-0.0.1-SNAPSHOT.jar"]

FROM alpine:3.20 AS standalone

COPY --from=front / /
COPY --from=back / /
COPY misc/docker/supervisor.ini /app/supervisor.ini
COPY misc/docker/Caddyfile.standalone /app/Caddyfile.standalone

RUN apk add --no-cache supervisor libcap \
    && addgroup -S appuser \
    && adduser -S -G appuser appuser \
    && setcap 'cap_net_bind_service=+ep' /usr/bin/caddy \
    && chown -R appuser:appuser /app

WORKDIR /app
USER appuser

CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]



