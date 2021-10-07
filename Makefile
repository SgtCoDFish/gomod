DEPS=$(wildcard *.go)

.PHONY: build
build: bin/gomod

.PHONY: clean
clean:
	@rm -rf bin

bin:
	@mkdir -p bin

bin/gomod: cmd/gomod/main.go $(DEPS) | bin
	CGO_ENABLED=0 go build -ldflags '-w -s' -o $@ $<

bin/gomod-armv7: cmd/gomod/main.go $(DEPS) | bin
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -ldflags '-w -s' -o $@ $<

.PHONY: test
test:
	go test ./...
