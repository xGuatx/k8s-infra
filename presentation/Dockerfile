# ==========================
# Stage 1 : Build frontend
# ==========================
FROM node:18 AS builder

WORKDIR /app

# Forcer IPv4 pour eviter les timeouts DNS
ENV NODE_OPTIONS=--dns-result-order=ipv4first

# Config npm pour limiter les timeouts et reessayer
RUN npm config set registry https://registry.npmjs.org/ \
    && npm config set prefer-offline true \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-factor 2 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000

# Copier uniquement package.json pour profiter du cache
COPY package*.json ./

# Installer les dependances (sans lockfile  npm install)
RUN npm install --verbose

# Copier le reste du projet
COPY . .

# Builder le projet (Vite va generer dist/)
RUN npm run build

# ==========================
# Stage 2 : Image finale avec Nginx
# ==========================
FROM nginx:alpine

# Copier le build genere
COPY --from=builder /app/dist /usr/share/nginx/html

# Copier ta config nginx custom
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]

