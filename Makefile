# === Tools === #
NASM    := nasm
AR      := ar
BUILD   := build
INCLUDE := include
MACROS  := src/macros
CC      := clang

# === ANSI Colors === #
RESET := \033[0m
BOLD  := \033[1m
GREEN := \033[32m
CYAN  := \033[36m
RED   := \033[31m

# === User configuration === #
ALGOS := sha2
PLATFORM ?= auto

ifeq ($(PLATFORM),auto)
  UNAME_S := $(shell uname -s 2>/dev/null || echo unknown)
  ifeq ($(UNAME_S),Linux)
    FORMAT := elf64
  else ifeq ($(UNAME_S),Darwin)
    FORMAT := macho64
  else
    FORMAT := win64
  endif
else ifeq ($(PLATFORM),linux)
  FORMAT := elf64
else ifeq ($(PLATFORM),macos)
  FORMAT := macho64
else ifeq ($(PLATFORM),windows)
  FORMAT := win64
else
  $(error Unknown PLATFORM value '$(PLATFORM)')
endif

# === Subalgorithm mapping === #
SHA2_SUBALGOS := sha2/sha256.asm

define ALGO_MAP
sha2-256 := sha2/sha256.asm
sha2     := $(SHA2_SUBALGOS)
endef
$(eval $(ALGO_MAP))

# === Files === #
SRC       := $(foreach algo,$(ALGOS),$(eval ALL_ASM_FILES += $($(algo))))
OBJ       := $(patsubst %.asm, $(BUILD)/%.o, $(ALL_ASM_FILES))
ARCHIVE   := $(BUILD)/libcrypto.a
TEST_SRCS := $(wildcard tests/*.c)
TEST_OBJS := $(patsubst tests/%.c, build/tests/%.o, $(TEST_SRCS))
BMRK_SRCS := $(wildcard benchmarks/*.c)
BMRK_OBJS := $(patsubst benchmarks/%.c, build/benchmarks/%.o, $(BMRK_SRCS))
LIBKRITIC := tests/KritiC/build/libkritic.a
ifeq ($(OS),Windows_NT)
	TESTRUNNER := $(BUILD)/testrunner.exe
	BENCHRUNNER := $(BUILD)/benchrunner.exe
else
	TESTRUNNER := $(BUILD)/testrunner
	BENCHRUNNER := $(BUILD)/benchrunner.exe
endif


# === Default target === #
all: banner $(ARCHIVE)

banner:
	@printf "===== [      Build libcrypto       ] =====\n"
	@printf " $(CYAN)$(BOLD)Building$(RESET)   asm-crypto for $(FORMAT) with algos/groups: $(ALGOS)\n"

# === Assemble === #
$(BUILD)/%.o: src/%.asm banner
	@if [ ! -d "$(dir $@)" ]; then mkdir -p "$(dir $@)"; fi; \
	if $(NASM) -f $(FORMAT) -o "$@" "$<"; then \
		printf " $(GREEN)$(BOLD)Assembled$(RESET)  $<\n"; \
	else \
		printf " $(RED)$(BOLD)Failed$(RESET)    $<\n"; \
		exit 1; \
	fi

# === Archive static library === #
$(ARCHIVE): $(OBJ)
	@printf " $(CYAN)$(BOLD)Archiving$(RESET)  $@\n"
	@if [ ! -d "$(dir $@)" ]; then \
		mkdir -p "$(dir $@)"; \
	fi
	@$(AR) rcs $@ $^
	@printf " $(GREEN)$(BOLD)Archived$(RESET)   at: $(ARCHIVE)\n"

build/tests/%.o: tests/%.c
	@if [ -z "$(TEST_BANNER_PRINTED)" ]; then \
		printf "===== [   Build libcrypto tests    ] =====\n"; \
	fi
	@$(eval TEST_BANNER_PRINTED := 1)
	@if [ ! -d "build/tests" ]; then \
		mkdir -p "build/tests"; \
	fi
	@printf " $(GREEN)$(BOLD)Compiling$(RESET) $<\n"
	@$(CC) $(CFLAGS) -c $< -o $@

build/benchmarks/%.o: benchmarks/%.c
	@if [ -z "$(BENCH_BANNER_PRINTED)" ]; then \
		printf "===== [ Build libcrypto benchmarks ] =====\n"; \
	fi
	@$(eval BENCH_BANNER_PRINTED := 1)
	@if [ ! -d "build/benchmarks" ]; then \
		mkdir -p "build/benchmarks"; \
	fi
	@printf " $(GREEN)$(BOLD)Compiling$(RESET) $<\n"
	@$(CC) $(CFLAGS) -c $< -o $@


# Rule: test depends on all test object files and the archive
$(LIBKRITIC):
	@printf "===== [  KritiC testing framework  ] =====\n"
	@if [ -d "tests/KritiC" ]; then \
		(cd tests/KritiC && make --no-print-directory static); \
	else \
		printf " $(RED)$(BOLD)Error:$(RESET) tests/KritiC does not exist!\n"; \
	fi

test: $(ARCHIVE) $(TEST_OBJS) $(LIBKRITIC)
	@printf "===== [      Linking tests      ] =====\n"
	@printf " $(GREEN)$(BOLD)Linking$(RESET)   $(TESTRUNNER)\n"
	@$(CC) -O3 $(TEST_OBJS) $(LIBKRITIC) $(ARCHIVE) -o $(TESTRUNNER)
	@printf " $(CYAN)$(BOLD)Running$(RESET)   $(TESTRUNNER)\n"
	@$(TESTRUNNER)

benchmark: $(ARCHIVE) $(BMRK_OBJS)
	@printf "===== [    Linking benchmarks    ] =====\n"
	@printf " $(GREEN)$(BOLD)Linking$(RESET)   $(BENCHRUNNER)\n"
	@$(CC) -O3 $(BMRK_OBJS) $(ARCHIVE) -o $(BENCHRUNNER) -lcrypto -lsodium -lbearssl
	@printf " $(CYAN)$(BOLD)Running$(RESET)   $(BENCHRUNNER)\n"
	@$(BENCHRUNNER)

# === Clean === #
clean:
	@if [ -d "build" ]; then \
		rm -rf build; \
	fi
	@if [ -d "tests/KritiC" ]; then \
		(cd tests/KritiC && make --no-print-directory clean); \
	fi
	@printf " $(GREEN)$(BOLD)Cleaned$(RESET)\n"

.PHONY: all clean headers banner
