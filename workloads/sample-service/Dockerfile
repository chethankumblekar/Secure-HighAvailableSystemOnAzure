# Multi-stage build: compile a static binary, ship it on a distroless base.
# No shell, no package manager, non-root by default — small attack surface
# on purpose, since Phase 3 scans this image with Trivy and signs it with
# cosign.

FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
