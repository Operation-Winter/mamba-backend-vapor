# syntax=docker/dockerfile:1

ARG SWIFT_VERSION=6.3.3

FROM swift:${SWIFT_VERSION}-noble AS build

WORKDIR /build

COPY Package.swift Package.resolved ./
RUN --mount=type=cache,target=/build/.build \
    --mount=type=cache,target=/root/.cache \
    swift package resolve

COPY Sources ./Sources
COPY Tests ./Tests

RUN --mount=type=cache,target=/build/.build \
    --mount=type=cache,target=/root/.cache \
    swift build -c release \
    && mkdir -p /staging \
    && cp .build/release/Run /staging/Run

FROM swift:${SWIFT_VERSION}-noble-slim AS runtime

WORKDIR /app

COPY --from=build --chown=10001:10001 --chmod=0555 /staging/Run /app/Run

USER 10001:10001

EXPOSE 8080
STOPSIGNAL SIGTERM

ENTRYPOINT ["/app/Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
