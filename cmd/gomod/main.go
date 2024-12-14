package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/coreos/go-systemd/v22/activation"
	"github.com/goproxy/goproxy"
)

var (
	cacheDir = flag.String("cache-dir", "/tmp/cache", "directory in which to cache modules")
	address  = flag.String("address", "127.0.0.1", "address on which to bind")
	systemd  = flag.Bool("systemd", false, "whether systemd socket activation is to be used")
	port     = flag.Int("port", 14115, "the port on which to listen")

	printVersion = flag.Bool("print-version", false, "if true, print the version number on startup")

	version = ""
)

func systemdListener() (net.Listener, error) {
	systemdListeners, err := activation.Listeners()
	if err != nil {
		return nil, fmt.Errorf("failed to get systemd activation listeners: %w", err)
	}

	if len(systemdListeners) != 1 {
		return nil, fmt.Errorf("expected one listener from systemd activation but got %d", len(systemdListeners))
	}

	return systemdListeners[0], nil
}

func standardListener() (net.Listener, error) {
	address := fmt.Sprintf("%s:%d", *address, *port)

	return net.Listen("tcp", address)
}

func run(logger *slog.Logger) error {
	flag.Parse()

	if *printVersion {
		logger.Info("gomod version", "version", version)
	}

	if err := os.MkdirAll(*cacheDir, 0o664); err != nil {
		return fmt.Errorf("failed to ensure dir %q exists: %w", *cacheDir, err)
	}

	var listener net.Listener
	var err error
	if *systemd {
		listener, err = systemdListener()
	} else {
		listener, err = standardListener()
	}

	if err != nil {
		return err
	}

	server := &http.Server{
		Handler: &goproxy.Goproxy{
			Cacher: goproxy.DirCacher(*cacheDir),
		},
	}

	sigs := make(chan os.Signal, 1)

	signal.Notify(sigs, syscall.SIGINT)

	go func() {
		err := server.Serve(listener)
		if err != nil && err != http.ErrServerClosed {
			logger.Error("failed to shut down server", "err", err)
			return
		}
	}()

	<-sigs
	logger.Info("shutting down server")

	err = server.Shutdown(context.Background())
	if err != nil {
		return err
	}

	return nil
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	err := run(logger)
	if err != nil {
		logger.Error("execution failed", "err", err, "version", version)
		os.Exit(1)
	}
}
