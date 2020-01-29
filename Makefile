ZETOPT_DIST_FILE	:= zetopt.sh
ZETOPT_SRC_DIR		:= ./src
ZETOPT_SRC_NAMES	:= info init main def validator parser data msg utils help man
ZETOPT_TEST_DIR		:= ./test
SHUNIT2_URL			:= https://github.com/kward/shunit2
SHUNIT2_DIR			:= ./.ignore/shunit2
SHUNIT2_BIN			:= $(SHUNIT2_DIR)/shunit2


.PHONY: all
all: test


.PHONY: build
build: $(ZETOPT_DIST_FILE)


$(ZETOPT_DIST_FILE): $(ZETOPT_SRC_DIR)/*
	@echo Build $(ZETOPT_DIST_FILE);\
	: > $(ZETOPT_DIST_FILE) &&\
	for name in $(ZETOPT_SRC_NAMES);\
	do\
		cat -- $(ZETOPT_SRC_DIR)/$$name.sh >> $(ZETOPT_DIST_FILE);\
		printf -- "%s\n\n" "" >> $(ZETOPT_DIST_FILE);\
	done


.PHONY: shunit2
shunit2:
	@test -f $(SHUNIT2_BIN) || git clone $(SHUNIT2_URL) $(SHUNIT2_DIR)


.PHONY: test
test: build shunit2
	@export SHUNIT2_BIN="$(realpath $(SHUNIT2_BIN))";\
	export ZETOPT_DIST_FILE="$(realpath $(ZETOPT_DIST_FILE))";\
	idx=1;\
	for shell in bash zsh;\
	do\
		if which $$shell >/dev/null 2>&1; then\
			for test_file in $(ZETOPT_TEST_DIR)/*;\
			do\
				printf -- ">> %s\n" "TEST $$idx" "Test $(ZETOPT_DIST_FILE) with shunit2 on $$shell" "Using: $$test_file";\
				$$shell $$test_file;\
				idx=$$((idx+1));\
			done\
		else\
			printf -- ">> %s\n" "Skip test on $$shell: $$shell not found";\
		fi;\
	done
