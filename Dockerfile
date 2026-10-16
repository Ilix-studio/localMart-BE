# syntax=docker/dockerfile:1.7
FROM node:22-bookworm-slim AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
# `prisma generate` runs in the build stage, once the schema is present.
RUN npm ci --ignore-scripts

FROM dependencies AS builder
WORKDIR /app
COPY . .
# Generating the client needs no database; prisma.config.ts tolerates a missing URL.
RUN npx prisma generate && npm run build

# One-shot image for `prisma migrate deploy` / seeding (needs the Prisma CLI and ts-node).
FROM builder AS migrate
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*
ENV DB_TARGET=production
CMD ["npx", "prisma", "migrate", "deploy"]

FROM node:22-bookworm-slim AS production-dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts

FROM node:22-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production \
    PORT=8080
RUN groupadd --system --gid 1001 nodejs && useradd --system --uid 1001 --gid nodejs appuser
COPY --from=production-dependencies --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:nodejs /app/package.json ./package.json
# tsc output includes the generated Prisma client (src/generated -> dist/generated).
COPY --from=builder --chown=appuser:nodejs /app/dist ./dist
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/_ah/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "dist/server.js"]
