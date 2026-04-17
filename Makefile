.PHONY: install serve build check

install:
	python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt

serve:
	@kill $$(lsof -ti :8001) 2>/dev/null || true
	.venv/bin/mkdocs serve --dev-addr=127.0.0.1:8001

build:
	.venv/bin/mkdocs build

check:
	.venv/bin/mkdocs build --strict
