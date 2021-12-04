GO=GCO_ENABLED=0 go
GOFLAGS := -ldflags '-w -s' -trimpath

GODEPS=cmd/gomod/main.go
DEPS=$(GODEPS) go.mod go.sum

VERSION := 0.0.1

CTR ?= podman

GOLANGCI_LINT ?= golangci-lint

.PHONY: build
build: bin/gomod

.PHONY: clean
clean:
	@rm -rf bin

.PHONY: ci
ci: test vet fmt golangci-lint binaries debs

.PHONY: vet
vet:
	@echo "+ $@"
	@$(GO) vet $(GODEPS)

.PHONY: fmt
fmt:
	@echo "+ $@"
	@if [[ ! -z "$(shell gofmt -l -s . | grep -v vendor | tee /dev/stderr)" ]]; then exit 1; fi

.PHONY: golangci-lint
golangci-lint:
	@echo "+ $@"
	@$(GOLANGCI_LINT) run

.PHONY: binaries
binaries: bin/gomod bin/gomod-linux-amd64 bin/gomod-linux-armv7l

bin bin/pkg_amd64/usr/bin bin/pkg_armv7l/usr/bin:
	@mkdir -p $@

bin/gomod: cmd/gomod/main.go $(DEPS) | bin
	$(GO) build $(GOFLAGS) -o $@ $<

bin/gomod-linux-amd64: cmd/gomod/main.go $(DEPS) | bin
	GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS) -o $@ $<

bin/gomod-linux-armv7l: cmd/gomod/main.go $(DEPS) | bin
	GOOS=linux GOARCH=arm GOARM=7 $(GO) build $(GOFLAGS) -o $@ $<

.PHONY: test
test:
	go test ./...

.PHONY: debs
debs: bin/gomod_$(VERSION)_amd64.deb bin/gomod_$(VERSION)_armv7l.deb

bin/pkg_%/usr/bin/gomod: bin/gomod-linux-% | bin/pkg_%/usr/bin
	cp $< $@

bin/gomod_$(VERSION)_amd64.deb bin/gomod_$(VERSION)_armv7l.deb: bin/gomod_$(VERSION)_%.deb: bin/pkg_%/usr/bin/gomod | bin
	@# fpm will refuse to overwrite an existing file so we need to remove first
	rm -f $@
	$(CTR) run -it --rm -v $(shell pwd)/:/fpm ghcr.io/sgtcodfish/fpm:1.14.0-6851b3d4 \
		--input-type dir --output-type deb \
		--name gomod \
		--package /fpm/$@ \
		--chdir /fpm/bin/pkg_$* \
		--vendor "Ashley Davis (SgtCoDFish)" \
		--maintainer "Ashley Davis (SgtCoDFish)" \
		--license "MIT" \
		--architecture $* \
		--url https://github.com/SgtCoDFish/gomod \
		--description "gomod is a tremendously simple caching go module proxy which runs almost anywhere" \
		.
