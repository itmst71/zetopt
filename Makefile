ZETOPT_SRC_FILES	:= info main init def parser data msg utils help man
SHUNIT2_URL			:= https://github.com/kward/shunit2
SHUNIT2_DIR			:= .ignore/shunit2
SHUNIT2_BIN			:= $(SHUNIT2_DIR)/shunit2

.DEFAULT_GOAL		:= test


.PHONY: dist
dist:
	@echo -n > zetopt.sh && \
	for src_file in $(ZETOPT_SRC_FILES); \
	do \
		cat -- src/$$src_file.sh >> zetopt.sh && \
		printf -- "%b" "\n\n" >> zetopt.sh; \
	done

.PHONY: shunit2
shunit2:
	@test -f $(SHUNIT2_BIN) || git clone $(SHUNIT2_URL) $(SHUNIT2_DIR)

.PHONY: test
test: shunit2
	@SHUNIT2_BIN=$(SHUNIT2_BIN) bash test/test.shunit2
	@SHUNIT2_BIN=$(SHUNIT2_BIN) zsh test/test.shunit2
