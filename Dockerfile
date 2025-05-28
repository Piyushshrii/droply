# -------- Base Stage --------
FROM node:18-alpine AS base

WORKDIR /app

RUN apk add --no-cache g++ make python3 py3-pip libc6-compat

COPY package*.json ./

EXPOSE 3000


# -------- Builder Stage --------
FROM base AS builder

WORKDIR /app

# Copy the rest of the application
COPY . .

# Accept build-time ENV variables to bypass need for `.env`
ARG DATABASE_URL
ENV DATABASE_URL=$DATABASE_URL

# Install ALL dependencies (including devDependencies)
RUN npm install

# Push schema using drizzle-kit
RUN npx drizzle-kit push

# Build the app (Tailwind/PostCSS included here)
RUN npm run build


# -------- Production Stage --------
FROM node:18-alpine AS production

WORKDIR /app

ENV NODE_ENV=production

# Create user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

USER nextjs

# Copy only the built output and deps
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

EXPOSE 3000

CMD ["npm", "start"]


# -------- Dev Stage --------
FROM base AS dev

ENV NODE_ENV=development

WORKDIR /app

COPY . .

RUN npm install

ARG DATABASE_URL
ENV DATABASE_URL=$DATABASE_URL

RUN npx drizzle-kit push

CMD ["npm", "run", "dev"]

