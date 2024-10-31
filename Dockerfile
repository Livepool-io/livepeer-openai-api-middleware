# Use a base image with Go 1.21.x for building the application
FROM golang:1.21 AS builder

# Set the working directory inside the container
WORKDIR /app

# Download all the dependencies
RUN go mod download

# prefetch the binaries, so that they will be cached and not downloaded on each change
RUN go run github.com/steebchen/prisma-client-go prefetch

COPY . ./

# Generate the Prisma Client Go client
RUN go generate ./db

# Build the Go application with CGO disabled and statically linked
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api .

# Use a minimal base image for running the application
FROM alpine:latest  

# Install ca-certificates
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/app .

# Expose the port the application runs on
EXPOSE 8080

# Set the entry point to run the binary
ENTRYPOINT ["./api"]