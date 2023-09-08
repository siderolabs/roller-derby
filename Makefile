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
BUILD := docker buildx build
PLATFORM ?= linux/amd64,linux/arm64
PROGRESS ?= auto
SOURCE_DATE_EPOCH ?= "1642703752"
PUSH ?= false
COMMON_ARGS := --file=Pkgfile
COMMON_ARGS += --provenance=false
COMMON_ARGS += --progress=$(PROGRESS)
COMMON_ARGS += --platform=$(PLATFORM)
COMMON_ARGS += --build-arg=http_proxy=$(http_proxy)
COMMON_ARGS += --build-arg=https_proxy=$(https_proxy)
COMMON_ARGS += --build-arg=SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH)
COMMON_ARGS += --build-arg=TAG=$(TAG)
COMMON_ARGS += --build-arg=PKGS=$(PKGS)

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

TARGETS = dummy

all: $(TARGETS)

.PHONY: $(TARGETS)
$(TARGETS):
	@if [ $(CI) ] && [ $(PUSH) = "true" ]; then \
		$(MAKE) docker-$@ TARGET_ARGS="--tag=$(REGISTRY_AND_USERNAME)/$@:$(TAG)-$(subst linux/,,$(PLATFORM)) --push=$(PUSH)"; \
	else \
		$(MAKE) docker-$@ TARGET_ARGS="--tag=$(REGISTRY_AND_USERNAME)/$@:$(TAG) --push=$(PUSH)"; \
	fi

push: ## Pushes all images built by this Makefile to the registry.
	@$(foreach target,$(TARGETS),crane index append -t $(REGISTRY)/$(USERNAME)/$(target):$(TAG) -m $(REGISTRY)/$(USERNAME)/$(target):$(TAG)-amd64 -m $(REGISTRY)/$(USERNAME)/$(target):$(TAG)-arm64;)
	@$(foreach target,$(TARGETS),crane push $(REGISTRY)/$(USERNAME)/$(target):$(TAG) ghcr.io/siderolabs/$(target):$(TAG);)

.PHONY: clean
clean:  ## Cleans up all artifacts.
	@rm -rf $(ARTIFACTS)

local-%: ## Builds the specified target defined in the Dockerfile using the local output type. The build result will be output to the specified local destination.
	@$(MAKE) target-$* TARGET_ARGS="--output=type=local,dest=$(DEST) $(TARGET_ARGS)"
	@PLATFORM=$(PLATFORM) \

target-%: ## Builds the specified target defined in the Dockerfile. The build result will only remain in the build cache.
	@$(BUILD) \
		--target=$* \
		$(COMMON_ARGS) \
		$(TARGET_ARGS) .

docker-%: ## Builds the specified target defined in the Dockerfile using the docker output type. The build result will be loaded into docker.
	@$(MAKE) target-$* TARGET_ARGS="$(TARGET_ARGS)"
