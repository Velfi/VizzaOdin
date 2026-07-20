APP := vizzaodin
.DEFAULT_GOAL := run
SRC := src
ZELDA_ENGINE_ROOT ?= ../zelda-engine
ZELDA_ENGINE_COLLECTION := -collection:zelda_engine=$(abspath $(ZELDA_ENGINE_ROOT))/packages
ODIN_PACKAGES := $(SRC) packages/app packages/game packages/render_vk
BUILD_DIR := build
SHADER_SRC := assets/shaders
SHADER_BUILD := $(BUILD_DIR)/shaders
PROFILE_MACOS_ENTITLEMENTS := config/profile-macos.entitlements
FONT_GENERATOR := scripts/generate_ui_font_bitmap.py
FONT_SOURCE := assets/fonts/ZeldaSans-Regular-v1.otf
FONT_BITMAP := assets/shaders/ui_font_bitmap.slang
FONT_ATLAS := assets/fonts/ui_font_atlas.png
FONT_METRICS := $(ZELDA_ENGINE_ROOT)/packages/ui/font_metrics.odin
FONT_LOGICAL_HEIGHT := 16
FONT_ATLAS_CELL_WIDTH := 32
FONT_ATLAS_CELL_HEIGHT := 32
FONT_ATLAS_COLUMNS := 16
FONT_ATLAS_FONT_SIZE := 84
TOMLC17_ROOT := third_party/tomlc17
TOMLC17_DIR := $(TOMLC17_ROOT)/src
TOMLC17_LIB := $(TOMLC17_DIR)/libtomlc17.a
TOMLC17_REPO := https://github.com/cktan/tomlc17.git
TOMLC17_REV ?= 91ba3cc1023364f6ff59afa87e10ecac7e9a1dce
TOMLC17_STAMP := $(TOMLC17_ROOT)/.vizzaodin-rev
TEXTSHAPE_DIR := $(ZELDA_ENGINE_ROOT)/third_party/textshape
TEXTSHAPE_LIB := $(TEXTSHAPE_DIR)/libtextshape.a
TEXTSHAPE_CFLAGS := $(shell pkg-config --cflags harfbuzz freetype2 2>/dev/null)
TEXTSHAPE_LIBS := $(shell pkg-config --libs harfbuzz freetype2 2>/dev/null)
STEAM_SDK_LOCATION ?= $(HOME)/steam_sdk
STEAM_APP_ID ?= 4945920
STEAM_DEFAULT_ENABLED ?= true
SLANG_BIN := $(CURDIR)/.tools/slang/bin
SLANGC := $(shell if [ -x "$(SLANG_BIN)/slangc" ]; then printf "%s" "$(SLANG_BIN)/slangc"; else command -v slangc 2>/dev/null; fi)
export PATH := $(SLANG_BIN):$(PATH)
MOLTENVK_PREFIX := $(shell brew --prefix molten-vk 2>/dev/null)
VULKAN_LOADER_PREFIX := $(shell brew --prefix vulkan-loader 2>/dev/null)
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
STEAM_REDIST_SUBDIR :=
STEAM_REDIST_FILE :=
ifeq ($(UNAME_S),Darwin)
STEAM_REDIST_SUBDIR := osx
STEAM_REDIST_FILE := libsteam_api.dylib
ifneq ($(MOLTENVK_PREFIX),)
ifneq ($(VULKAN_LOADER_PREFIX),)
MACOS_VULKAN_ENV := VK_ICD_FILENAMES=$(MOLTENVK_PREFIX)/etc/vulkan/icd.d/MoltenVK_icd.json DYLD_LIBRARY_PATH=$(MOLTENVK_PREFIX)/lib:$(VULKAN_LOADER_PREFIX)/lib
endif
endif
endif
ifeq ($(UNAME_S),Linux)
STEAM_REDIST_FILE := libsteam_api.so
ifeq ($(UNAME_M),aarch64)
STEAM_REDIST_SUBDIR := linuxarm64
else ifeq ($(UNAME_M),arm64)
STEAM_REDIST_SUBDIR := linuxarm64
else ifeq ($(UNAME_M),i386)
STEAM_REDIST_SUBDIR := linux32
else ifeq ($(UNAME_M),i686)
STEAM_REDIST_SUBDIR := linux32
else
STEAM_REDIST_SUBDIR := linux64
endif
endif
STEAM_REDIST_SRC := $(STEAM_SDK_LOCATION)/redistributable_bin/$(STEAM_REDIST_SUBDIR)/$(STEAM_REDIST_FILE)
ODIN_FLAGS ?= -o:none
override ODIN_FLAGS += $(ZELDA_ENGINE_COLLECTION)

.PHONY: help run run-macos-vulkan build build-steam run-steam copy-steam-redist check check-boundaries test perf-particle-life fmt clean distclean shaders deps install-slangc mcp mcp-macos-vulkan theme-preview theme-preview-mcp ui-component profile-ui-trace package-macos steam-upload-preview ui-font-atlas tomlc17 textshape

help:
	@printf '%s\n' \
		'Development:' \
		'  run                 Build shaders/app and run it' \
		'  run-steam           Build and run with Steam enabled' \
		'  mcp                 Build and run in MCP mode' \
		'  theme-preview       Build and run the theme preview' \
		'  theme-preview-mcp   Run the theme preview in MCP mode' \
		'  ui-component       Render one component (COMPONENT=number STATE=editing)' \
		'  profile-ui-trace    Build, launch, and record an Instruments trace' \
		'' \
		'Build and validation:' \
		'  build               Build build/vizzaodin' \
		'  build-steam         Build with Steam and copy its redistributable' \
		'  shaders             Compile Slang shaders into build/shaders' \
		'  check               Check package boundaries and Odin sources' \
		'  test                Run Odin tests' \
		'  perf-particle-life  Run the headless Particle Life GPU benchmark' \
		'  fmt                 Format Odin packages' \
		'  deps                Build native dependencies' \
		'  ui-font-atlas       Regenerate UI font assets and metrics' \
		'' \
		'Release and maintenance:' \
		'  package-macos       Build dist/Vizza.app and dist/Vizza-macos.zip' \
		'  steam-upload-preview  Validate a local Steam upload (VERSION=x.y.z)' \
		'  install-slangc      Install the repo-local Slang compiler' \
		'  clean               Remove build/' \
		'  distclean           Remove build/, dist/, and build-staging/' \
		'' \
		'Profiling variables: DURATION=30s TEMPLATE="Metal System Trace" OUTPUT=profiles/name.trace' \
		'Build variables: ODIN_FLAGS=-o:none STEAM_SDK_LOCATION=~/steam_sdk STEAM_APP_ID=4945920'

run: shaders build
	$(MACOS_VULKAN_ENV) $(BUILD_DIR)/$(APP)

run-steam: shaders build-steam
	$(MACOS_VULKAN_ENV) $(BUILD_DIR)/$(APP) --steam

run-macos-vulkan: run

mcp: shaders build
	$(MACOS_VULKAN_ENV) $(BUILD_DIR)/$(APP) --mcp

mcp-macos-vulkan: mcp

theme-preview: shaders build
	$(MACOS_VULKAN_ENV) $(BUILD_DIR)/$(APP) --theme-preview

theme-preview-mcp: shaders build
	$(MACOS_VULKAN_ENV) $(BUILD_DIR)/$(APP) --theme-preview --mcp

ui-component: shaders build
	python3 scripts/render_ui_component.py "$${COMPONENT:-number}" --state "$${STATE:-rest}" --value "$${VALUE:-0.58}" $${OUTPUT:+--output "$$OUTPUT"}

profile-ui-trace: shaders build
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		codesign --force --sign - --entitlements "$(PROFILE_MACOS_ENTITLEMENTS)" "$(BUILD_DIR)/$(APP)"; \
	fi
	./scripts/profile_gpu_trace.sh --duration "$${DURATION:-30s}" --template "$${TEMPLATE:-Metal System Trace}" --output "$${OUTPUT:-profiles/vizzaodin-ui-render.trace}"

ui-font-atlas: $(FONT_BITMAP) $(FONT_ATLAS) $(FONT_METRICS)

$(FONT_BITMAP) $(FONT_ATLAS) $(FONT_METRICS): $(FONT_SOURCE) $(FONT_GENERATOR) Makefile
	python3 $(FONT_GENERATOR) --font $(FONT_SOURCE) --output $(FONT_BITMAP) --atlas-output $(FONT_ATLAS) --metrics-output $(FONT_METRICS) --glyph-first 32 --glyph-last 126 --cell-width $(FONT_ATLAS_CELL_WIDTH) --cell-height $(FONT_ATLAS_CELL_HEIGHT) --columns $(FONT_ATLAS_COLUMNS) --logical-height $(FONT_LOGICAL_HEIGHT) --font-size $(FONT_ATLAS_FONT_SIZE) --supersample 1

build: $(TEXTSHAPE_LIB) $(TOMLC17_LIB)
	mkdir -p $(BUILD_DIR)
	odin build $(SRC) $(ODIN_FLAGS) -extra-linker-flags:"$(TEXTSHAPE_LIBS)" -out:$(BUILD_DIR)/$(APP)

build-steam: $(TEXTSHAPE_LIB) $(TOMLC17_LIB)
	mkdir -p $(BUILD_DIR)
	odin build $(SRC) $(ODIN_FLAGS) -define:VIZZA_STEAM_DEFAULT_ENABLED=$(STEAM_DEFAULT_ENABLED) -define:VIZZA_STEAM_APP_ID=$(STEAM_APP_ID) -extra-linker-flags:"$(TEXTSHAPE_LIBS)" -out:$(BUILD_DIR)/$(APP)
	$(MAKE) copy-steam-redist

copy-steam-redist:
	@if [ -z "$(STEAM_REDIST_SUBDIR)" ] || [ -z "$(STEAM_REDIST_FILE)" ]; then printf 'Steam redistributable copy is not configured for %s/%s\n' "$(UNAME_S)" "$(UNAME_M)" >&2; exit 1; fi
	@if [ ! -f "$(STEAM_REDIST_SRC)" ]; then printf 'Steam redistributable not found: %s\nSet STEAM_SDK_LOCATION to a Steamworks SDK root.\n' "$(STEAM_REDIST_SRC)" >&2; exit 1; fi
	mkdir -p $(BUILD_DIR)
	cp "$(STEAM_REDIST_SRC)" "$(BUILD_DIR)/$(STEAM_REDIST_FILE)"

package-macos:
	./scripts/package_macos.sh

steam-upload-preview:
	@test -n "$(VERSION)" || (printf 'Set VERSION, e.g. make steam-upload-preview VERSION=0.1.0\n' >&2; exit 1)
	./scripts/steam-upload.sh --preview --local "$(VERSION)"

check: check-boundaries $(TEXTSHAPE_LIB) $(TOMLC17_LIB)
	bash ./scripts/check_vulkan13.sh
	odin check $(SRC) $(ZELDA_ENGINE_COLLECTION)

check-boundaries:
	./scripts/check_package_boundaries.sh

test: $(TEXTSHAPE_LIB) $(TOMLC17_LIB)
	odin test $(SRC) $(ZELDA_ENGINE_COLLECTION) -extra-linker-flags:"$(TEXTSHAPE_LIBS)"

perf-particle-life: shaders $(TEXTSHAPE_LIB) $(TOMLC17_LIB)
	mkdir -p $(BUILD_DIR)
	odin build perf/particle_life $(ODIN_FLAGS) -extra-linker-flags:"$(TEXTSHAPE_LIBS)" -out:$(BUILD_DIR)/particle_life_perf
	$(MACOS_VULKAN_ENV) $(BUILD_DIR)/particle_life_perf $(ARGS)

deps: $(TEXTSHAPE_LIB) $(TOMLC17_LIB)

tomlc17: $(TOMLC17_LIB)

$(TOMLC17_STAMP):
	mkdir -p third_party
	@if [ -e "$(TOMLC17_ROOT)" ] && [ ! -d "$(TOMLC17_ROOT)/.git" ]; then printf 'Remove %s or turn it into a git clone before running make deps.\n' "$(TOMLC17_ROOT)" >&2; exit 1; fi
	@if [ ! -d "$(TOMLC17_ROOT)/.git" ]; then git clone "$(TOMLC17_REPO)" "$(TOMLC17_ROOT)"; fi
	git -C "$(TOMLC17_ROOT)" fetch --depth 1 origin "$(TOMLC17_REV)"
	git -C "$(TOMLC17_ROOT)" checkout --detach "$(TOMLC17_REV)"
	printf '%s\n' "$(TOMLC17_REV)" > "$(TOMLC17_STAMP)"

$(TOMLC17_LIB): $(TOMLC17_STAMP)
	$(MAKE) -C $(TOMLC17_DIR)

textshape: $(TEXTSHAPE_LIB)

$(TEXTSHAPE_LIB): $(TEXTSHAPE_DIR)/textshape.c
	cc -c $(TEXTSHAPE_CFLAGS) $(TEXTSHAPE_DIR)/textshape.c -o $(TEXTSHAPE_DIR)/textshape.o
	ar rcs $(TEXTSHAPE_LIB) $(TEXTSHAPE_DIR)/textshape.o

install-slangc:
	./scripts/install_slangc.sh

shaders:
	test -n "$(SLANGC)"
	mkdir -p $(SHADER_BUILD)
	./scripts/build_shaders.sh $(SLANGC) $(SHADER_SRC) $(SHADER_BUILD)
	bash ./scripts/check_shader_manifest.sh $(SHADER_BUILD)/slang-manifest.txt

fmt:
	for pkg in $(ODIN_PACKAGES); do odin strip-semicolon $$pkg -no-entry-point; done
	for pkg in $(ZELDA_ENGINE_ROOT)/packages/engine $(ZELDA_ENGINE_ROOT)/packages/ui; do odin strip-semicolon $$pkg -no-entry-point; done

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
	rm -rf dist build-staging
