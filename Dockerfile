FROM node:lts

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY --chown=node:node . .

ENV NODE_ENV=production HOST=0.0.0.0
EXPOSE 3000

USER node
CMD ["node", "index.js", "--serve"]
