package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/sgtcodfish/gomod"

	"github.com/goproxy/goproxy"
)

var (
	cacheDir = flag.String("cache-dir", "/tmp/cache", "directory in which to cache modules")
	address  = flag.String("address", "127.0.0.1", "address on which to bind")
	port     = flag.Int("port", 14115, "the port on which to listen")
)

func main() {
	flag.Parse()

	if err := os.MkdirAll(*cacheDir, 0o664); err != nil {
		log.Fatalf("failed to ensure dir %q exists: %v", *cacheDir, err)
	}

	server := &http.Server{
		Handler: &goproxy.Goproxy{
			Cacher: gomod.DirCacher(*cacheDir),
		},
		Addr: fmt.Sprintf("%s:%d", *address, *port),
	}

	log.Printf("listening on %s", server.Addr)

	sigs := make(chan os.Signal, 1)

	signal.Notify(sigs, syscall.SIGINT)

	go func() {
		err := server.ListenAndServe()
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
