ARG NODE_VERSION=20

FROM node:${NODE_VERSION}-alpine as builder

# Install pnpm
RUN corepack enable && corepack prepare pnpm@9 --activate

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml ./


# Copy source code
COPY . /app

# Build the application
RUN pnpm build


# Production stage
FROM nginx:alpine-slim

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]