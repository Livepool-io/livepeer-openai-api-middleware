# Use a base image with Go 1.21.x for pulling the repository and building the application
FROM golang:1.21 AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy from local
COPY . .
# Pull the repository
# RUN git clone https://github.com/Livepool-io/livepeer-openai-api-middleware.git .

# Download all the dependencies
RUN go mod download

# Build the Go application
RUN go build -o app

# Use a minimal base image for running the application
FROM debian:bullseye-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/app .

# Expose the port the application runs on
EXPOSE 8080

# Set the entry point to run the binary with the gateway flag
ENTRYPOINT ["./app"]
