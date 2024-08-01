package main

import (
	"log"

	"github.com/livepool-io/openai-middleware/middleware"
	"github.com/livepool-io/openai-middleware/server"
)

// 1. Set up a new Golang project for the middleware.
// 2. Create endpoints that mirror OpenAI's chat completion API.
// 3. Translate incoming OpenAI-style requests to your API's format.
// 4. Forward the translated request to your existing API.
// 5. Transform the response back to OpenAI's format.
// 6. Handle both streaming and non-streaming responses.

func main() {
	gateway := middleware.NewGateway("http://your-api-host")
	server, err := server.NewServer(gateway)
	if err != nil {
		log.Fatalf("Failed to create server: %v", err)
	}
	if err := server.Start("8080"); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
