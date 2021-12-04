GO=GCO_ENABLED=0 go
GOFLAGS := -ldflags '-w -s' -trimpath
DEPS=$(wildcard *.go) go.mod go.sum

VERSION := 0.0.1

.PHONY: build
build: bin/gomod

.PHONY: clean
clean:
	@rm -rf bin

.PHONY: ci
ci: test binaries

.PHONY: binaries
binaries: bin/gomod bin/gomod-linux-amd64 bin/gomod-linux-armv7

bin:
	@mkdir -p $@

bin/gomod: cmd/gomod/main.go $(DEPS) | bin
	$(GO) build $(GOFLAGS) -o $@ $<

bin/gomod-linux-amd64: cmd/gomod/main.go $(DEPS) | bin
	GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS) -o $@ $<

bin/gomod-linux-armv7: cmd/gomod/main.go $(DEPS) | bin
	GOOS=linux GOARCH=arm GOARM=7 $(GO) build $(GOFLAGS) -o $@ $<

.PHONY: test
test:
	go test ./...
