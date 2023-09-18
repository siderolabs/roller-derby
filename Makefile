# THIS FILE WAS AUTOMATICALLY GENERATED, PLEASE DO NOT EDIT.
#
# Generated on 2023-09-18T10:59:04Z by kres 90499df-dirty.

# common variables

SHA := $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG := $(shell git describe --tag --always --dirty)
ABBREV_TAG := $(shell git describe --tags >/dev/null 2>/dev/null && git describe --tag --always --match v[0-9]\* --abbrev=0 || echo 'undefined')
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
ARTIFACTS := _out
WITH_DEBUG ?= false
WITH_RACE ?= false
REGISTRY ?= ghcr.io
USERNAME ?= siderolabs
REGISTRY_AND_USERNAME ?= $(REGISTRY)/$(USERNAME)
PROTOBUF_GO_VERSION ?= 1.31.0
GRPC_GO_VERSION ?= 1.3.0
GRPC_GATEWAY_VERSION ?= 2.18.0
VTPROTOBUF_VERSION ?= 0.5.0
DEEPCOPY_VERSION ?= v0.5.5
GOLANGCILINT_VERSION ?= v1.54.2
GOFUMPT_VERSION ?= v0.5.0
GO_VERSION ?= 1.21.1
GOIMPORTS_VERSION ?= v0.13.0
GO_BUILDFLAGS ?=
GO_LDFLAGS ?=
CGO_ENABLED ?= 0
GOTOOLCHAIN ?= local
GOEXPERIMENT ?= loopvar
TESTPKGS ?= ./...
KRES_IMAGE ?= ghcr.io/siderolabs/kres:latest
CONFORMANCE_IMAGE ?= ghcr.io/siderolabs/conform:latest

# docker build settings

BUILD := docker buildx build
PLATFORM ?= linux/amd64
PROGRESS ?= auto
PUSH ?= false
CI_ARGS ?=
COMMON_ARGS = --file=Dockerfile
COMMON_ARGS += --provenance=false
COMMON_ARGS += --progress=$(PROGRESS)
COMMON_ARGS += --platform=$(PLATFORM)
COMMON_ARGS += --push=$(PUSH)
COMMON_ARGS += --build-arg=ARTIFACTS="$(ARTIFACTS)"
COMMON_ARGS += --build-arg=SHA="$(SHA)"
COMMON_ARGS += --build-arg=TAG="$(TAG)"
COMMON_ARGS += --build-arg=ABBREV_TAG="$(ABBREV_TAG)"
COMMON_ARGS += --build-arg=USERNAME="$(USERNAME)"
COMMON_ARGS += --build-arg=REGISTRY="$(REGISTRY)"
COMMON_ARGS += --build-arg=TOOLCHAIN="$(TOOLCHAIN)"
COMMON_ARGS += --build-arg=CGO_ENABLED="$(CGO_ENABLED)"
COMMON_ARGS += --build-arg=GO_BUILDFLAGS="$(GO_BUILDFLAGS)"
COMMON_ARGS += --build-arg=GO_LDFLAGS="$(GO_LDFLAGS)"
COMMON_ARGS += --build-arg=GOTOOLCHAIN="$(GOTOOLCHAIN)"
COMMON_ARGS += --build-arg=GOEXPERIMENT="$(GOEXPERIMENT)"
COMMON_ARGS += --build-arg=PROTOBUF_GO_VERSION="$(PROTOBUF_GO_VERSION)"
COMMON_ARGS += --build-arg=GRPC_GO_VERSION="$(GRPC_GO_VERSION)"
COMMON_ARGS += --build-arg=GRPC_GATEWAY_VERSION="$(GRPC_GATEWAY_VERSION)"
COMMON_ARGS += --build-arg=VTPROTOBUF_VERSION="$(VTPROTOBUF_VERSION)"
COMMON_ARGS += --build-arg=DEEPCOPY_VERSION="$(DEEPCOPY_VERSION)"
COMMON_ARGS += --build-arg=GOLANGCILINT_VERSION="$(GOLANGCILINT_VERSION)"
COMMON_ARGS += --build-arg=GOIMPORTS_VERSION="$(GOIMPORTS_VERSION)"
COMMON_ARGS += --build-arg=GOFUMPT_VERSION="$(GOFUMPT_VERSION)"
COMMON_ARGS += --build-arg=TESTPKGS="$(TESTPKGS)"
TOOLCHAIN ?= docker.io/golang:1.21-alpine

# help menu

export define HELP_MENU_HEADER
# Getting Started

To build this project, you must have the following installed:

- git
- make
- docker (19.03 or higher)

## Creating a Builder Instance

The build process makes use of experimental Docker features (buildx).
To enable experimental features, add 'experimental: "true"' to '/etc/docker/daemon.json' on
Linux or enable experimental features in Docker GUI for Windows or Mac.

To create a builder instance, run:

	docker buildx create --name local --use


If you already have a compatible builder instance, you may use that instead.

## Artifacts

All artifacts will be output to ./$(ARTIFACTS). Images will be tagged with the
registry "$(REGISTRY)", username "$(USERNAME)", and a dynamic tag (e.g. $(IMAGE):$(TAG)).
The registry and username can be overridden by exporting REGISTRY, and USERNAME
respectively.

endef

ifneq (, $(filter $(CI), t true TRUE y yes 1))
GITHUB_BRANCH := $(subst /,-,${GITHUB_HEAD_REF})
GITHUB_BRANCH := $(subst +,-,$(GITHUB_BRANCH))
CI_ARGS := --cache-from=type=registry,ref=registry.dev.siderolabs.io/${GITHUB_REPOSITORY}:buildcache-main --cache-from=type=registry,ref=registry.dev.siderolabs.io/${GITHUB_REPOSITORY}:buildcache-$(GITHUB_BRANCH) --cache-to=type=registry,ref=registry.dev.siderolabs.io/${GITHUB_REPOSITORY}:buildcache-$(GITHUB_BRANCH),mode=max
endif

ifneq (, $(filter $(WITH_RACE), t true TRUE y yes 1))
GO_BUILDFLAGS += -race
CGO_ENABLED := 1
GO_LDFLAGS += -linkmode=external -extldflags '-static'
endif

ifneq (, $(filter $(WITH_DEBUG), t true TRUE y yes 1))
GO_BUILDFLAGS += -tags sidero.debug
else
GO_LDFLAGS += -s -w
endif

all: unit-tests roller-derby image-roller-derby lint

.PHONY: clean
clean:  ## Cleans up all artifacts.
	@rm -rf $(ARTIFACTS)

target-%:  ## Builds the specified target defined in the Dockerfile. The build result will only remain in the build cache.
	@$(BUILD) --target=$* $(COMMON_ARGS) $(TARGET_ARGS) $(CI_ARGS) .

local-%:  ## Builds the specified target defined in the Dockerfile using the local output type. The build result will be output to the specified local destination.
	@$(MAKE) target-$* TARGET_ARGS="--output=type=local,dest=$(DEST) $(TARGET_ARGS)"

lint-golangci-lint:  ## Runs golangci-lint linter.
	@$(MAKE) target-$@

lint-gofumpt:  ## Runs gofumpt linter.
	@$(MAKE) target-$@

.PHONY: fmt
fmt:  ## Formats the source code
	@docker run --rm -it -v $(PWD):/src -w /src golang:$(GO_VERSION) \
		bash -c "export GOEXPERIMENT=loopvar; export GOTOOLCHAIN=local; \
		export GO111MODULE=on; export GOPROXY=https://proxy.golang.org; \
		go install mvdan.cc/gofumpt@$(GOFUMPT_VERSION) && \
		gofumpt -w ."

lint-govulncheck:  ## Runs govulncheck linter.
	@$(MAKE) target-$@

lint-goimports:  ## Runs goimports linter.
	@$(MAKE) target-$@

.PHONY: base
base:  ## Prepare base toolchain
	@$(MAKE) target-$@

.PHONY: unit-tests
unit-tests:  ## Performs unit tests
	@$(MAKE) local-$@ DEST=$(ARTIFACTS)

.PHONY: unit-tests-race
unit-tests-race:  ## Performs unit tests with race detection enabled.
	@$(MAKE) target-$@

.PHONY: coverage
coverage:  ## Upload coverage data to codecov.io.
	bash -c "bash <(curl -s https://codecov.io/bash) -f $(ARTIFACTS)/coverage-unit-tests.txt -X fix"

.PHONY: $(ARTIFACTS)/roller-derby-darwin-amd64
$(ARTIFACTS)/roller-derby-darwin-amd64:
	@$(MAKE) local-roller-derby-darwin-amd64 DEST=$(ARTIFACTS)

.PHONY: roller-derby-darwin-amd64
roller-derby-darwin-amd64: $(ARTIFACTS)/roller-derby-darwin-amd64  ## Builds executable for roller-derby-darwin-amd64.

.PHONY: $(ARTIFACTS)/roller-derby-darwin-arm64
$(ARTIFACTS)/roller-derby-darwin-arm64:
	@$(MAKE) local-roller-derby-darwin-arm64 DEST=$(ARTIFACTS)

.PHONY: roller-derby-darwin-arm64
roller-derby-darwin-arm64: $(ARTIFACTS)/roller-derby-darwin-arm64  ## Builds executable for roller-derby-darwin-arm64.

.PHONY: $(ARTIFACTS)/roller-derby-linux-amd64
$(ARTIFACTS)/roller-derby-linux-amd64:
	@$(MAKE) local-roller-derby-linux-amd64 DEST=$(ARTIFACTS)

.PHONY: roller-derby-linux-amd64
roller-derby-linux-amd64: $(ARTIFACTS)/roller-derby-linux-amd64  ## Builds executable for roller-derby-linux-amd64.

.PHONY: $(ARTIFACTS)/roller-derby-linux-arm64
$(ARTIFACTS)/roller-derby-linux-arm64:
	@$(MAKE) local-roller-derby-linux-arm64 DEST=$(ARTIFACTS)

.PHONY: roller-derby-linux-arm64
roller-derby-linux-arm64: $(ARTIFACTS)/roller-derby-linux-arm64  ## Builds executable for roller-derby-linux-arm64.

.PHONY: roller-derby
roller-derby: roller-derby-darwin-amd64 roller-derby-darwin-arm64 roller-derby-linux-amd64 roller-derby-linux-arm64  ## Builds executables for roller-derby.

.PHONY: lint-markdown
lint-markdown:  ## Runs markdownlint.
	@$(MAKE) target-$@

.PHONY: lint
lint: lint-golangci-lint lint-gofumpt lint-govulncheck lint-goimports lint-markdown  ## Run all linters for the project.

.PHONY: image-roller-derby
image-roller-derby:  ## Builds image for roller-derby.
	@$(MAKE) target-$@ TARGET_ARGS="--tag=$(REGISTRY)/$(USERNAME)/roller-derby:$(TAG)"

.PHONY: rekres
rekres:
	@docker pull $(KRES_IMAGE)
	@docker run --rm -v $(PWD):/src -w /src -e GITHUB_TOKEN $(KRES_IMAGE)

.PHONY: help
help:  ## This help menu.
	@echo "$$HELP_MENU_HEADER"
	@grep -E '^[a-zA-Z%_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: release-notes
release-notes:
	mkdir -p $(ARTIFACTS)
	@ARTIFACTS=$(ARTIFACTS) ./hack/release.sh $@ $(ARTIFACTS)/RELEASE_NOTES.md $(TAG)

.PHONY: conformance
conformance:
	@docker pull $(CONFORMANCE_IMAGE)
	@docker run --rm -it -v $(PWD):/src -w /src $(CONFORMANCE_IMAGE) enforce

