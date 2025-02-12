# Build stage
FROM golang:1.20-alpine AS builder

WORKDIR /app

# Copy Go module files and generate/update go.sum
COPY go.mod ./
RUN go mod tidy

# Download dependencies
RUN go mod download

# Copy the rest of the application code
COPY . .

# Build the Go binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o app .

# Final stage
FROM alpine:3.21

WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /app/app .

# Copy static assets (CSS, JS, HTML templates)
COPY static /app/static
COPY templates /app/templates

# Expose the application port
EXPOSE 5000

# Run the application
CMD ["./app"]
