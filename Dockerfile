# Stage 1: Build the Go application
FROM golang:1.27-alpine AS builder

# Set the working directory
WORKDIR /app

# Copy Go dependency files first
COPY Server/MuchToDo/go.mod Server/MuchToDo/go.sum ./

# Download dependencies
RUN go mod download

# Copy the application source code
COPY Server/MuchToDo/ .

# Compile the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /app/much-to-do ./cmd/api

# Stage 2: Production runtime
FROM alpine:3.22 AS runtime

# Install CA certificates for secure connections
RUN apk add --no-cache ca-certificates

# Create a non-root application user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set the working directory
WORKDIR /app

# Copy the compiled application from the builder stage
COPY --from=builder --chown=appuser:appgroup /app/much-to-do /app/much-to-do

# Switch to the non-root user
USER appuser

# Application port
EXPOSE 8080

# Start the application
ENTRYPOINT ["/app/much-to-do"]

# Check API health every 30 seconds
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1