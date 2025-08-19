# Development
.SERVICE_TARGETS := frontend backend

$(.SERVICE_TARGETS):
	@echo ""

.FLAGS := no-cache capsule

$(.FLAGS):
	@echo ""

.PHONY: dev

dev dev-help dev-standalone dev-detached dev-attached dev-stop dev-exec dev-enter dev-clean dev-build:
	@bash dev/make-dev.sh $@ "$(filter-out $@, $(MAKECMDGOALS))" "$(ARGS)"

# Tests

run-tests:
	pytest

lint:
	bash dev/run-lint.sh
