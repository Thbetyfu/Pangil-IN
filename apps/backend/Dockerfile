# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# Copy dependency files
COPY package*.json ./
COPY prisma ./prisma/

# Install build dependencies
RUN npm ci

# Generate Prisma Client
RUN npx prisma generate

# Copy source code and config
COPY . .

# Build TypeScript source
RUN npm run build

# Remove development packages
RUN npm prune --production


# Stage 2: Production Run
FROM node:20-alpine

WORKDIR /usr/src/app

# Copy production artifacts from builder stage
COPY --from=builder /usr/src/app/package*.json ./
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/prisma ./prisma
COPY --from=builder /usr/src/app/public ./public

# Set production environment variable
ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

CMD ["node", "dist/index.js"]
