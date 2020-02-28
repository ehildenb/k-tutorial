# Settings
# --------

BUILD_DIR     := .build
SUBDEFN_DIR   := .
DEFN_BASE_DIR := $(BUILD_DIR)/defn
DEFN_DIR      := $(DEFN_BASE_DIR)/$(SUBDEFN_DIR)

DEPS_DIR          := deps
K_DIR             := $(abspath $(BUILD_DIR))/k
K_RELEASE_TAR     := $(abspath $(BUILD_DIR))/k.tar.gz
K_RELEASE_TAR_URL := $(shell cat $(abspath $(DEPS_DIR))/k.release)/k-nightly.tar.gz

K_RELEASE ?= $(K_DIR)/k-distribution/target/release/k
K_BIN     := $(K_RELEASE)/bin
K_LIB     := $(K_RELEASE)/lib
export K_RELEASE

PATH := $(K_BIN):$(PATH)
export PATH

# need relative path for `pandoc` on MacOS
PANDOC_TANGLE_SUBMODULE := $(DEPS_DIR)/pandoc-tangle
TANGLER                 := $(PANDOC_TANGLE_SUBMODULE)/tangle.lua
LUA_PATH                := $(PANDOC_TANGLE_SUBMODULE)/?.lua;;
export TANGLER
export LUA_PATH

.PHONY: clean distclean         \
        deps deps-k deps-tangle \
        defn defn-imp-k         \
        build build-imp-k       \
        test

all: build split-tests

clean:
	rm -rf $(DEFN_BASE_DIR)

distclean:
	rm -rf $(BUILD_DIR)

# Dependencies
# ------------

deps: deps-k deps-tangle

deps-k:      $(K_RELEASE)/lib/java/kernel-1.0-SNAPSHOT.jar
deps-tangle: $(TANGLER)

$(K_RELEASE)/lib/java/kernel-1.0-SNAPSHOT.jar:
	mkdir -p $(BUILD_DIR)
	rm -rf $(K_DIR) $(K_RELEASE_TAR)
	curl --location --output $(K_RELEASE_TAR) $(K_RELEASE_TAR_URL)
	mkdir -p $(K_RELEASE)
	tar --extract --file $(K_RELEASE_TAR) --strip-components 1 --directory $(K_RELEASE)
	krun --version

$(TANGLER):
	git submodule update --init -- $(PANDOC_TANGLE_SUBMODULE)

# Building
# --------

imp_k_module := IMP
imp_k_dir    := $(DEFN_DIR)/k/imp
imp_k_files  := $(imp_k_dir)/imp-k.k

imp_k_kompiled := $(imp_k_dir)/imp-kompiled/interpreter

# Tangle definition from *.md files

tangle := .k

defn: defn-imp-k
defn-imp-k: $(defn_imp_k_files)

$(imp_k_dir)/%.k: %.md $(TANGLER)
	@mkdir -p $(imp_k_dir)
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:"$(tangle)" $< > $@

# Kompiling

build: build-imp-k
build-imp-k: $(imp_k_kompiled)

KOMPILE_OPTS += -ccopt -std=c++14 -O2

# IMP K Kompiled

$(imp_k_kompiled): $(imp_k_files)
	$(K_BIN)/kompile --main-module $(imp_k_module) --backend llvm             \
	                 --syntax-module $(imp_k_module) $(imp_k_dir)/imp-k.k     \
	                 --directory $(imp_k_dir) -I $(imp_k_dir) -I $(imp_k_dir) \
	                 $(KOMPILE_OPTS)