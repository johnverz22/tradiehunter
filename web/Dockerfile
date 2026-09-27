# Fixo Admin Web — React Development Dockerfile
# Used by docker-compose.yml for local dev with hot reload.

FROM node:20-alpine AS dev

WORKDIR /app

# Install dependencies first (layer cache)
COPY package*.json ./
RUN npm install

# Copy everything else
COPY . .

# Expose port
EXPOSE 3000

# Use Vite dev server with host binding for Docker.
# Re-install on startup so the /app/node_modules anonymous volume stays populated
# and in sync with package*.json (bind mount hides image-layer node_modules).
CMD ["sh", "-c", "npm install && npm run dev -- --host 0.0.0.0 --port 3000"]
