FROM node:24-bookworm-slim
ENV NODE_ENV=production HOST=0.0.0.0 MYAGENDA_DATA=/app/data
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund && mkdir data && chown node:node data
COPY src ./src
USER node
EXPOSE 8787
CMD ["node", "src/index.mjs"]
