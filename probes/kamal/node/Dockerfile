FROM node:22-alpine AS build
WORKDIR /app
COPY package.json index.html src.jsx server.mjs ./
RUN npm install && npm run build && npm prune --omit=dev
FROM node:22-alpine
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json server.mjs ./
EXPOSE 3000
CMD ["node", "server.mjs"]
