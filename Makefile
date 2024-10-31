# Default target
all: db build

# Build the Go application
build:
	go build openai-api.go

db:
	go generate ./db