package main

import (
	"flag"
	"log"

	"github.com/livepool-io/openai-middleware/middleware"
	"github.com/livepool-io/openai-middleware/server"
)

func main() {
	gatewayURL := flag.String("gateway", "http://your-api-host", "The URL of the gateway API")
	port := flag.String("port", "8080", "The port to run the server on")
	flag.Parse()
	gateway := middleware.NewGateway(*gatewayURL)
	server, err := server.NewServer(gateway)
	if err != nil {
		log.Fatalf("Failed to create server: %v", err)
	}
	if err := server.Start(*port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
