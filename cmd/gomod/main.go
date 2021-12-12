package main

import (
	"context"
	"flag"
	"fmt"
	"log"
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
)

func main() {
	flag.Parse()

	if err := os.MkdirAll(*cacheDir, 0o664); err != nil {
		log.Fatalf("failed to ensure dir %q exists: %v", *cacheDir, err)
	}

	var listener net.Listener
	if *systemd {
		systemdListeners, err := activation.Listeners()
		if err != nil {
			log.Fatalf("systemd activation in use but failed to get listeners: %s", err.Error())
		}

		if len(systemdListeners) != 1 {
			log.Fatalf("expected one listener from systemd activation but got %d", len(systemdListeners))
		}

		listener = systemdListeners[0]
	} else {
		address := fmt.Sprintf("%s:%d", *address, *port)

		var err error

		listener, err = net.Listen("tcp", address)
		if err != nil {
			log.Fatalf("failed to create TCP listener: %s", err.Error())
		}

		log.Printf("listening on %s", address)
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
			log.Fatalf("failed to listen: %v", err)
		}
	}()

	<-sigs
	log.Println("shutting down server")

	err := server.Shutdown(context.Background())
	if err != nil {
		log.Fatalf("failed to shutdown server: %v", err)
	}
}
