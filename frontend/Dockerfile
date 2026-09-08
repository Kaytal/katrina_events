# Two targets from one file:
#   --target dev   node running esbuild in watch mode, serving on :3001 (compose dev)
#   --target prod  esbuild build -> nginx serving dist/ (Phase 11)
#
# Node 24 is the current LTS. Local development may run a newer odd-numbered
# release; .nvmrc pins the version to reconcile them.
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

FROM deps AS dev
COPY . .
EXPOSE 3001
CMD ["node", "esbuild.config.mjs", "--watch"]

FROM deps AS build
COPY . .
ENV NODE_ENV=production
RUN node esbuild.config.mjs

FROM nginx:alpine AS prod
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
