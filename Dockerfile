FROM golang:1.26.4-alpine AS build
WORKDIR /src

COPY game/go.mod game/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY game/ ./
ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    go test ./internal/... ./cmd/server && \
    go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server
RUN mkdir -p /runtime-data && chown 10001:10001 /runtime-data && chmod 700 /runtime-data

FROM scratch
WORKDIR /app
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/server /app/server
COPY --from=build --chown=10001:10001 /runtime-data /data
USER 10001:10001
EXPOSE 18080
ENTRYPOINT ["/app/server"]
CMD ["-listen", "0.0.0.0:18080", "-save", "/data/server.pb", "-token-file", "/run/secrets/game_token"]
