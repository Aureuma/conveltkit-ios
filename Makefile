.PHONY: build test

build:
	./scripts/build-guard.sh swift build --jobs 2

test:
	./scripts/build-guard.sh swift test --jobs 2
