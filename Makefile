ZETOPT_SRC_NAMES	:= info main init def parser data msg utils help man
SHUNIT2_URL			:= https://github.com/kward/shunit2
SHUNIT2_DIR			:= .ignore/shunit2
SHUNIT2_BIN			:= $(SHUNIT2_DIR)/shunit2


.PHONY: all
all: test


.PHONY: build
build: zetopt.sh


zetopt.sh: src/*.sh
	@echo Build zetopt.sh;\
	rm zetopt.sh &&\
	for name in $(ZETOPT_SRC_NAMES);\
	do\
		cat -- src/$$name.sh >> zetopt.sh;\
		printf -- "%s\n\n" "" >> zetopt.sh;\
	done


.PHONY: shunit2
shunit2:
	@test -f $(SHUNIT2_BIN) || git clone $(SHUNIT2_URL) $(SHUNIT2_DIR)


.PHONY: test
test: build shunit2
	@for shell in bash zsh;\
	do\
		if which $$shell >/dev/null 2>&1; then\
			printf -- "%s\n" ">> Test zetopt.sh with shunit2 on $$shell";\
			SHUNIT2_BIN=$(SHUNIT2_BIN) $$shell test/test.shunit2;\
		else\
			printf -- "%s\n" ">> Skip test on $$shell: $$shell not found";\
		fi;\
	done

