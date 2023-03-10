# Variables
# ---------

# manual
V8_VERSION := 11.1.134

# auto
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	OS := linux
else ifeq ($(UNAME_S),Darwin)
	OS := macos
else
	$(error "OS not supported")
endif
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
	ARCH := X86_64
else ifeq ($(UNAME_M),aarch64)
	ARCH := aarch64
else ifeq ($(UNAME_M),arm64)
	ARCH := aarch64
else
	$(error "CPU not supported")
endif
ifeq ($(OS), "macos" && ($(ARCH), "X86_64"))
	$(error "OS/CPU not supported")
endif


# Infos
# -----
.PHONY: help

## Display this help screen
help:
	@printf "\e[36m%-35s %s\e[0m\n" "Command" "Usage"
	@sed -n '/^## /{\
		s/## //g;\
		h;\
		n;\
		s/:.*//g;\
		G;\
		s/\n/ /g;\
		p;}' Makefile | awk '{printf "\033[33m%-35s\033[0m%s\n", $$1, substr($$0,length($$1)+1)}'

# Git commands
git_clean := git diff --quiet; echo $$?
git_current_branch := git branch --show-current
git_last_commit_full := git log --pretty=format:'%cd_%h' -n 1 --date=format:'%Y-%m-%d_%H-%M'


# Dependancies
# ------------
.PHONY: vendor

V8_VERSION=11.1.134

## Fetch dependancies (op access required)
vendor:
	@printf "\e[36mUpdating git submodules dependancies ...\e[0m\n" && \
	git submodule update --init --recursive && \
	git submodule update --remote && \
	printf "=> Done\n" && \
	printf "\e[36mDownloading v8 static library from s3 for \e[32m$(ARCH)-$(OS) \e[36m...\e[0m\n" && \
	mkdir -p vendor/v8 && \
	op run --env-file="vendor/.env" -- aws s3 sync s3://browsercore/v8/$(V8_VERSION)/$(ARCH)-$(OS) vendor/v8 && \
	printf "=> Done\n"


# Zig commands
# ------------
.PHONY: build build-release run run-release shell test bench

## Build in debug mode
build:
	@printf "\e[36mBuilding (debug, stage2)...\e[0m\n"
	@zig build bench || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mBuild OK\e[0m\n"

build-release:
	@printf "\e[36mBuilding (release safe, stage2)...\e[0m\n"
	@zig build bench -Drelease-safe || (printf "\e[33mBuild ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mBuild OK\e[0m\n"

## Run the benchmark in release-safe mode
run: build-release
	@printf "\e[36mRunning...\e[0m\n"
	@./zig-out/bin/jsruntime-bench || (printf "\e[33mRun ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mRun OK\e[0m\n"

## Run a JS shell in release-safe mode
shell: build-release
	@printf "\e[36mRunning...\e[0m\n"
	@./zig-out/bin/jsruntime-shell || (printf "\e[33mRun ERROR\e[0m\n"; exit 1;)

## Test
test:
	@printf "\e[36mTesting...\e[0m\n"
	@zig build test || (printf "\e[33mTest ERROR\e[0m\n"; exit 1;)
	@printf "\e[33mTest OK\e[0m\n"

## run + save results in benchmarks dir
bench: build-release
# Check repo is clean
ifneq ($(shell $(git_clean)), 0)
	$(error repo is not clean)
endif
	@mkdir -p benchmarks && \
	./zig-out/bin/jsruntime-bench > benchmarks/$(shell $(git_last_commit_full))_$(shell $(git_current_branch)).txt