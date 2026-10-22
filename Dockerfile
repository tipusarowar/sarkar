# BanglaGov-LLM - container for internal pilot deployment
# Build:  docker build -t banglagov-llm .
# Run:    docker run -p 3000:3000 --env-file .env -v banglagov-data:/app/data banglagov-llm
FROM node:22-slim

WORKDIR /app
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=3000

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY . .
RUN mkdir -p /app/data && chown -R node:node /app/data

# The SQLite database lives in /app/data - mount a volume so it survives restarts
VOLUME ["/app/data"]
EXPOSE 3000

USER node
CMD ["node", "server/server.js"]
