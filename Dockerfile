# syntax = docker/dockerfile-upstream:1.15.1-labs

# THIS FILE WAS AUTOMATICALLY GENERATED, PLEASE DO NOT EDIT.
#
# Generated on 2025-05-07T06:11:20Z by kres 1a0156b-dirty.

ARG TOOLCHAIN

FROM ghcr.io/siderolabs/ca-certificates:v1.10.0 AS image-ca-certificates

FROM ghcr.io/siderolabs/fhs:v1.10.0 AS image-fhs

# runs markdownlint
FROM docker.io/oven/bun:1.2.12-alpine AS lint-markdown
WORKDIR /src
RUN bun i markdownlint-cli@0.44.0 sentences-per-line@0.3.0
COPY .markdownlint.json .
COPY ./CHANGELOG.md ./CHANGELOG.md
RUN bunx markdownlint --ignore "CHANGELOG.md" --ignore "**/node_modules/**" --ignore '**/hack/chglog/**' --rules sentences-per-line .

# base toolchain image
FROM --platform=${BUILDPLATFORM} ${TOOLCHAIN} AS toolchain
RUN apk --update --no-cache add bash curl build-base protoc protobuf-dev

# build tools
FROM --platform=${BUILDPLATFORM} toolchain AS tools
ENV GO111MODULE=on
ARG CGO_ENABLED
ENV CGO_ENABLED=${CGO_ENABLED}
ARG GOTOOLCHAIN
ENV GOTOOLCHAIN=${GOTOOLCHAIN}
ARG GOEXPERIMENT
ENV GOEXPERIMENT=${GOEXPERIMENT}
ENV GOPATH=/go
ARG DEEPCOPY_VERSION
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg go install github.com/siderolabs/deep-copy@${DEEPCOPY_VERSION} \
	&& mv /go/bin/deep-copy /bin/deep-copy
ARG GOLANGCILINT_VERSION
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCILINT_VERSION} \
	&& mv /go/bin/golangci-lint /bin/golangci-lint
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg go install golang.org/x/vuln/cmd/govulncheck@latest \
	&& mv /go/bin/govulncheck /bin/govulncheck
ARG GOFUMPT_VERSION
RUN go install mvdan.cc/gofumpt@${GOFUMPT_VERSION} \
	&& mv /go/bin/gofumpt /bin/gofumpt

# tools and sources
FROM tools AS base
WORKDIR /src
COPY go.mod go.mod
COPY go.sum go.sum
RUN cd .
RUN --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg go mod download
RUN --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg go mod verify
COPY ./cmd ./cmd
RUN --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg go list -mod=readonly all >/dev/null

FROM tools AS embed-generate
ARG SHA
ARG TAG
WORKDIR /src
RUN mkdir -p internal/version/data && \
    echo -n ${SHA} > internal/version/data/sha && \
    echo -n ${TAG} > internal/version/data/tag

# runs gofumpt
FROM base AS lint-gofumpt
RUN FILES="$(gofumpt -l .)" && test -z "${FILES}" || (echo -e "Source code is not formatted with 'gofumpt -w .':\n${FILES}"; exit 1)

# runs golangci-lint
FROM base AS lint-golangci-lint
WORKDIR /src
COPY .golangci.yml .
ENV GOGC=50
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/root/.cache/golangci-lint,id=roller-derby/root/.cache/golangci-lint,sharing=locked --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg golangci-lint run --config .golangci.yml

# runs govulncheck
FROM base AS lint-govulncheck
WORKDIR /src
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg govulncheck ./...

# runs unit-tests with race detector
FROM base AS unit-tests-race
WORKDIR /src
ARG TESTPKGS
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg --mount=type=cache,target=/tmp,id=roller-derby/tmp CGO_ENABLED=1 go test -v -race -count 1 ${TESTPKGS}

# runs unit-tests
FROM base AS unit-tests-run
WORKDIR /src
ARG TESTPKGS
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg --mount=type=cache,target=/tmp,id=roller-derby/tmp go test -v -covermode=atomic -coverprofile=coverage.txt -coverpkg=${TESTPKGS} -count 1 ${TESTPKGS}

FROM embed-generate AS embed-abbrev-generate
WORKDIR /src
ARG ABBREV_TAG
RUN echo -n 'undefined' > internal/version/data/sha && \
    echo -n ${ABBREV_TAG} > internal/version/data/tag

FROM scratch AS unit-tests
COPY --from=unit-tests-run /src/coverage.txt /coverage-unit-tests.txt

# cleaned up specs and compiled versions
FROM scratch AS generate
COPY --from=embed-abbrev-generate /src/internal/version internal/version

# builds roller-derby-darwin-amd64
FROM base AS roller-derby-darwin-amd64-build
COPY --from=generate / /
COPY --from=embed-generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
ARG VERSION_PKG="internal/version"
ARG SHA
ARG TAG
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg GOARCH=amd64 GOOS=darwin go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS} -X ${VERSION_PKG}.Name=roller-derby -X ${VERSION_PKG}.SHA=${SHA} -X ${VERSION_PKG}.Tag=${TAG}" -o /roller-derby-darwin-amd64

# builds roller-derby-darwin-arm64
FROM base AS roller-derby-darwin-arm64-build
COPY --from=generate / /
COPY --from=embed-generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
ARG VERSION_PKG="internal/version"
ARG SHA
ARG TAG
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg GOARCH=arm64 GOOS=darwin go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS} -X ${VERSION_PKG}.Name=roller-derby -X ${VERSION_PKG}.SHA=${SHA} -X ${VERSION_PKG}.Tag=${TAG}" -o /roller-derby-darwin-arm64

# builds roller-derby-linux-amd64
FROM base AS roller-derby-linux-amd64-build
COPY --from=generate / /
COPY --from=embed-generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
ARG VERSION_PKG="internal/version"
ARG SHA
ARG TAG
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg GOARCH=amd64 GOOS=linux go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS} -X ${VERSION_PKG}.Name=roller-derby -X ${VERSION_PKG}.SHA=${SHA} -X ${VERSION_PKG}.Tag=${TAG}" -o /roller-derby-linux-amd64

# builds roller-derby-linux-arm64
FROM base AS roller-derby-linux-arm64-build
COPY --from=generate / /
COPY --from=embed-generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
ARG VERSION_PKG="internal/version"
ARG SHA
ARG TAG
RUN --mount=type=cache,target=/root/.cache/go-build,id=roller-derby/root/.cache/go-build --mount=type=cache,target=/go/pkg,id=roller-derby/go/pkg GOARCH=arm64 GOOS=linux go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS} -X ${VERSION_PKG}.Name=roller-derby -X ${VERSION_PKG}.SHA=${SHA} -X ${VERSION_PKG}.Tag=${TAG}" -o /roller-derby-linux-arm64

FROM scratch AS roller-derby-darwin-amd64
COPY --from=roller-derby-darwin-amd64-build /roller-derby-darwin-amd64 /roller-derby-darwin-amd64

FROM scratch AS roller-derby-darwin-arm64
COPY --from=roller-derby-darwin-arm64-build /roller-derby-darwin-arm64 /roller-derby-darwin-arm64

FROM scratch AS roller-derby-linux-amd64
COPY --from=roller-derby-linux-amd64-build /roller-derby-linux-amd64 /roller-derby-linux-amd64

FROM scratch AS roller-derby-linux-arm64
COPY --from=roller-derby-linux-arm64-build /roller-derby-linux-arm64 /roller-derby-linux-arm64

FROM roller-derby-linux-${TARGETARCH} AS roller-derby

FROM scratch AS roller-derby-all
COPY --from=roller-derby-darwin-amd64 / /
COPY --from=roller-derby-darwin-arm64 / /
COPY --from=roller-derby-linux-amd64 / /
COPY --from=roller-derby-linux-arm64 / /

FROM scratch AS image-roller-derby
ARG TARGETARCH
COPY --from=roller-derby roller-derby-linux-${TARGETARCH} /roller-derby
COPY --from=image-fhs / /
COPY --from=image-ca-certificates / /
LABEL org.opencontainers.image.source=https://github.com/siderolabs/roller-derby
ENTRYPOINT ["/roller-derby"]

