FROM node:20-alpine AS base
WORKDIR /app
RUN apk add --no-cache dumb-init

# ── Dependencies ───────────────────────────────────────────────────────────────
FROM base AS deps
COPY package*.json ./
RUN npm ci --ignore-scripts

# ── Development ────────────────────────────────────────────────────────────────
FROM deps AS development
COPY . .
RUN npx prisma generate
EXPOSE 3001
CMD ["npm", "run", "dev"]

# ── Build ──────────────────────────────────────────────────────────────────────
FROM deps AS build
COPY . .
RUN npx prisma generate
RUN npm run build

# ── Production ─────────────────────────────────────────────────────────────────
FROM base AS production
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY package.json ./

RUN npx prisma generate --schema=./prisma/schema.prisma

EXPOSE 3001
USER node
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]
