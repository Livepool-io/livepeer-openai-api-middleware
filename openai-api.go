package main

import (
	"flag"
	"log"

	"github.com/livepool-io/openai-middleware/db"
	"github.com/livepool-io/openai-middleware/middleware"
	"github.com/livepool-io/openai-middleware/server"
)

func main() {
	gatewayURL := flag.String("gateway", "http://your-api-host", "The URL of the gateway API")
	port := flag.String("port", "8080", "The port to run the server on")
	dbURL := flag.String("db-url", "http://your-db-host", "The URL of the database")
	dbKey := flag.String("db-key", "your-db-key", "The key to access the database")

	flag.Parse()

	apiKeyStore, err := db.NewSupabaseAPIKeyStore(*dbURL, *dbKey)
	if err != nil {
		log.Fatalf("Failed to create Supabase API key store: %v", err)
	}

	gateway := middleware.NewGateway(*gatewayURL)
	auth := middleware.NewAuthMiddleware(apiKeyStore)

	server, err := server.NewServer(auth, gateway)
	if err != nil {
		log.Fatalf("Failed to create server: %v", err)
	}
	if err := server.Start(*port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
