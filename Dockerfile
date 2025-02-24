# Build stage
FROM golang:1.21-alpine AS builder

# Install necessary build tools
RUN apk add --no-cache gcc musl-dev

# Set working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build -o /app/trading-service ./cmd/trading-service

# Final stage
FROM alpine:3.19

# Install necessary runtime dependencies
RUN apk add --no-cache ca-certificates postgresql-client

# Set working directory
WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/trading-service .

# Expose the application port
EXPOSE 8080

# Command to run the application
CMD ["./trading-service"]
