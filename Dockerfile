# syntax = docker/dockerfile-upstream:1.6.0-labs

# THIS FILE WAS AUTOMATICALLY GENERATED, PLEASE DO NOT EDIT.
#
# Generated on 2023-09-02T16:54:40Z by kres 431bf4f-dirty.

ARG TOOLCHAIN

# cleaned up specs and compiled versions
FROM scratch AS generate

FROM ghcr.io/siderolabs/ca-certificates:v1.5.0 AS image-ca-certificates

FROM ghcr.io/siderolabs/fhs:v1.5.0 AS image-fhs

# base toolchain image
FROM ${TOOLCHAIN} AS toolchain
RUN apk --update --no-cache add bash curl build-base protoc protobuf-dev

# build tools
FROM --platform=${BUILDPLATFORM} toolchain AS tools
ENV GO111MODULE on
ARG CGO_ENABLED
ENV CGO_ENABLED ${CGO_ENABLED}
ARG GOTOOLCHAIN
ENV GOTOOLCHAIN ${GOTOOLCHAIN}
ARG GOEXPERIMENT
ENV GOEXPERIMENT ${GOEXPERIMENT}
ENV GOPATH /go
ARG DEEPCOPY_VERSION
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg go install github.com/siderolabs/deep-copy@${DEEPCOPY_VERSION} \
	&& mv /go/bin/deep-copy /bin/deep-copy
ARG GOLANGCILINT_VERSION
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg go install github.com/golangci/golangci-lint/cmd/golangci-lint@${GOLANGCILINT_VERSION} \
	&& mv /go/bin/golangci-lint /bin/golangci-lint
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg go install golang.org/x/vuln/cmd/govulncheck@latest \
	&& mv /go/bin/govulncheck /bin/govulncheck
ARG GOIMPORTS_VERSION
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg go install golang.org/x/tools/cmd/goimports@${GOIMPORTS_VERSION} \
	&& mv /go/bin/goimports /bin/goimports
ARG GOFUMPT_VERSION
RUN go install mvdan.cc/gofumpt@${GOFUMPT_VERSION} \
	&& mv /go/bin/gofumpt /bin/gofumpt

# tools and sources
FROM tools AS base
WORKDIR /src
COPY go.mod go.mod
COPY go.sum go.sum
RUN cd .
RUN --mount=type=cache,target=/go/pkg go mod download
RUN --mount=type=cache,target=/go/pkg go mod verify
COPY ./cmd ./cmd
RUN --mount=type=cache,target=/go/pkg go list -mod=readonly all >/dev/null

# runs gofumpt
FROM base AS lint-gofumpt
RUN FILES="$(gofumpt -l .)" && test -z "${FILES}" || (echo -e "Source code is not formatted with 'gofumpt -w .':\n${FILES}"; exit 1)

# runs goimports
FROM base AS lint-goimports
RUN FILES="$(goimports -l -local github.com/siderolabs/roller-derby/ .)" && test -z "${FILES}" || (echo -e "Source code is not formatted with 'goimports -w -local github.com/siderolabs/roller-derby/ .':\n${FILES}"; exit 1)

# runs golangci-lint
FROM base AS lint-golangci-lint
WORKDIR /src
COPY .golangci.yml .
ENV GOGC 50
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/root/.cache/golangci-lint --mount=type=cache,target=/go/pkg golangci-lint run --config .golangci.yml

# runs govulncheck
FROM base AS lint-govulncheck
WORKDIR /src
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg govulncheck ./...

# builds roller-derby-darwin-amd64
FROM base AS roller-derby-darwin-amd64-build
COPY --from=generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg GOARCH=amd64 GOOS=darwin go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS}" -o /roller-derby-darwin-amd64

# builds roller-derby-darwin-arm64
FROM base AS roller-derby-darwin-arm64-build
COPY --from=generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg GOARCH=arm64 GOOS=darwin go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS}" -o /roller-derby-darwin-arm64

# builds roller-derby-linux-amd64
FROM base AS roller-derby-linux-amd64-build
COPY --from=generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg GOARCH=amd64 GOOS=linux go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS}" -o /roller-derby-linux-amd64

# builds roller-derby-linux-arm64
FROM base AS roller-derby-linux-arm64-build
COPY --from=generate / /
WORKDIR /src/cmd/roller-derby
ARG GO_BUILDFLAGS
ARG GO_LDFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg GOARCH=arm64 GOOS=linux go build ${GO_BUILDFLAGS} -ldflags "${GO_LDFLAGS}" -o /roller-derby-linux-arm64

# runs unit-tests with race detector
FROM base AS unit-tests-race
WORKDIR /src
ARG TESTPKGS
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg --mount=type=cache,target=/tmp CGO_ENABLED=1 go test -v -race -count 1 ${TESTPKGS}

# runs unit-tests
FROM base AS unit-tests-run
WORKDIR /src
ARG TESTPKGS
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg --mount=type=cache,target=/tmp go test -v -covermode=atomic -coverprofile=coverage.txt -coverpkg=${TESTPKGS} -count 1 ${TESTPKGS}

FROM scratch AS roller-derby-darwin-amd64
COPY --from=roller-derby-darwin-amd64-build /roller-derby-darwin-amd64 /roller-derby-darwin-amd64

FROM scratch AS roller-derby-darwin-arm64
COPY --from=roller-derby-darwin-arm64-build /roller-derby-darwin-arm64 /roller-derby-darwin-arm64

FROM scratch AS roller-derby-linux-amd64
COPY --from=roller-derby-linux-amd64-build /roller-derby-linux-amd64 /roller-derby-linux-amd64

FROM scratch AS roller-derby-linux-arm64
COPY --from=roller-derby-linux-arm64-build /roller-derby-linux-arm64 /roller-derby-linux-arm64

FROM scratch AS unit-tests
COPY --from=unit-tests-run /src/coverage.txt /coverage-unit-tests.txt

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
LABEL org.opencontainers.image.source https://github.com/siderolabs/roller-derby
ENTRYPOINT ["/roller-derby"]

