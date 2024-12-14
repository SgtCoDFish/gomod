BINDIR=_bin

GO=GCO_ENABLED=0 go
GOFLAGS := -ldflags '-w -s -X main.version=$(VERSION)' -trimpath

GODEPS=cmd/gomod/main.go
DEPS=$(GODEPS) go.mod go.sum

VERSION := 0.2.0

CTR ?= podman

GOLANGCI_LINT ?= golangci-lint

.PHONY: build
build: $(BINDIR)/gomod

.PHONY: clean
clean:
	@rm -rf $(BINDIR)

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
binaries: $(BINDIR)/gomod $(BINDIR)/gomod-linux-amd64 $(BINDIR)/gomod-linux-arm64 $(BINDIR)/gomod-linux-armv7l

.PHONY: binaries-ctr
binaries-ctr:
	$(CTR) run -it --rm -v $(shell pwd)/:/usr/src/gomod -w /usr/src/gomod docker.io/library/golang:1.17-stretch make binaries

$(BINDIR) $(BINDIR)/pkg_amd64/usr/bin $(BINDIR)/pkg_arm64/usr/bin $(BINDIR)/pkg_armv7l/usr/bin $(BINDIR)/pkg_amd64/usr/lib/sysusers.d $(BINDIR)/pkg_arm64/usr/lib/sysusers.d $(BINDIR)/pkg_armv7l/usr/lib/sysusers.d $(BINDIR)/pkg_amd64/usr/lib/systemd/system $(BINDIR)/pkg_arm64/usr/lib/systemd/system $(BINDIR)/pkg_armv7l/usr/lib/systemd/system:
	@mkdir -p $@

$(BINDIR)/gomod: cmd/gomod/main.go $(DEPS) | $(BINDIR)
	$(GO) build $(GOFLAGS) -o $@ $<

$(BINDIR)/gomod-linux-amd64: cmd/gomod/main.go $(DEPS) | $(BINDIR)
	GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS) -o $@ $<

$(BINDIR)/gomod-linux-arm64: cmd/gomod/main.go $(DEPS) | $(BINDIR)
	GOOS=linux GOARCH=arm64 $(GO) build $(GOFLAGS) -o $@ $<

$(BINDIR)/gomod-linux-armv7l: cmd/gomod/main.go $(DEPS) | $(BINDIR)
	GOOS=linux GOARCH=arm GOARM=7 $(GO) build $(GOFLAGS) -o $@ $<

.PHONY: test
test:
	go test ./...

.PHONY: systemd-activate
systemd-activate: ./$(BINDIR)/gomod
	systemd-socket-activate -l 127.0.0.1:14115 ./$(BINDIR)/gomod -systemd

.PHONY: debs
debs: $(BINDIR)/gomod_$(VERSION)_amd64.deb $(BINDIR)/gomod_$(VERSION)_arm64.deb $(BINDIR)/gomod_$(VERSION)_armv7l.deb

$(BINDIR)/pkg_%/usr/bin/gomod: $(BINDIR)/gomod-linux-% | $(BINDIR)/pkg_%/usr/bin
	cp $< $@

$(BINDIR)/pkg_%/usr/lib/systemd/system/gomod.service: dist/usr/lib/systemd/system/gomod.service | $(BINDIR)/pkg_%/usr/lib/systemd/system
	cp $< $@

$(BINDIR)/pkg_%/usr/lib/systemd/system/gomod.socket: dist/usr/lib/systemd/system/gomod.socket | $(BINDIR)/pkg_%/usr/lib/systemd/system
	cp $< $@

$(BINDIR)/pkg_%/usr/lib/sysusers.d/gomod.conf: dist/usr/lib/sysusers.d/gomod.conf | $(BINDIR)/pkg_%/usr/lib/sysusers.d
	cp $< $@

$(BINDIR)/gomod_$(VERSION)_amd64.deb $(BINDIR)/gomod_$(VERSION)_arm64.deb $(BINDIR)/gomod_$(VERSION)_armv7l.deb: $(BINDIR)/gomod_$(VERSION)_%.deb: $(BINDIR)/pkg_%/usr/bin/gomod $(BINDIR)/pkg_%/usr/lib/sysusers.d/gomod.conf $(BINDIR)/pkg_%/usr/lib/systemd/system/gomod.service | $(BINDIR)
	@# fpm will refuse to overwrite an existing file so we need to remove first
	rm -f $@
	$(CTR) run -it --rm -v $(shell pwd)/:/fpm ghcr.io/sgtcodfish/fpm:1.14.0-6851b3d4 \
		--input-type dir --output-type deb \
		--name gomod \
		--package /fpm/$@ \
		--chdir /fpm/$(BINDIR)/pkg_$* \
		--vendor "Ashley Davis (SgtCoDFish)" \
		--maintainer "Ashley Davis (SgtCoDFish)" \
		--license "MIT" \
		--architecture $* \
		--url https://github.com/SgtCoDFish/gomod \
		--description "gomod is a tremendously simple caching go module proxy which runs almost anywhere" \
		.
