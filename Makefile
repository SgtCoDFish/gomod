.PHONY: build
build: bin/gomod

.PHONY: clean
clean:
	@rm -rf bin

bin/gomod: main.go
	@mkdir -p bin
	CGO_ENABLED=0 go build -ldflags '-w -s' -o $@ $<

bin/gomod-armv7: main.go
	@mkdir -p bin
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -ldflags '-w -s' -o $@ $<
