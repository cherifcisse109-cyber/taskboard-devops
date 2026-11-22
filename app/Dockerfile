# syntax=docker/dockerfile:1

# Version de runtime Node injectee par Jenkins (build parallele 18 / 20 / 22)
ARG NODE_VERSION=20

# ---------- Stage 1 : build + tests unitaires ----------
FROM node:${NODE_VERSION}-alpine AS build
WORKDIR /app
COPY package.json ./
# Aucune dependance externe : npm ci/install reste rapide, mais la couche
# est conservee pour profiter du cache Docker si des dependances sont ajoutees.
RUN npm install --omit=dev --no-audit --no-fund
COPY server.js ./
COPY test ./test
# Le build echoue si les tests unitaires echouent
RUN npm test

# ---------- Stage 2 : image runtime minimale ----------
FROM node:${NODE_VERSION}-alpine AS runtime
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="taskboard-api" \
      org.opencontainers.image.version="${APP_VERSION}"
ENV NODE_ENV=production PORT=3000
WORKDIR /app
COPY --from=build /app/package.json /app/server.js ./
# Execution en utilisateur non-root (utilisateur "node" fourni par l'image)
USER node
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"
CMD ["node", "server.js"]
