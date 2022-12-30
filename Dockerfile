# base node image
FROM node:16-bullseye-slim as base

# set for base and all layer that inherit from it
ENV NODE_ENV production

# Install openssl for Prisma
RUN apt-get update && apt-get install -y openssl sqlite3

# Install all node_modules, including dev dependencies
FROM base as deps

WORKDIR /40scoreboard

ADD package.json package-lock.json ./
RUN npm install --production=false

# Setup production node_modules
FROM base as production-deps

WORKDIR /40scoreboard

COPY --from=deps /40scoreboard/node_modules /40scoreboard/node_modules
ADD package.json package-lock.json ./
RUN npm prune --production

# Build the app
FROM base as build

WORKDIR /40scoreboard

COPY --from=deps /40scoreboard/node_modules /40scoreboard/node_modules

ADD prisma .
RUN npx prisma generate

ADD . .
RUN npm run build

# Finally, build the production image with minimal footprint
FROM base

ENV DATABASE_URL=file:/data/sqlite.db
ENV PORT="8080"
ENV NODE_ENV="production"

# add shortcut for connecting to database CLI
RUN echo "#!/bin/sh\nset -x\nsqlite3 \$DATABASE_URL" > /usr/local/bin/database-cli && chmod +x /usr/local/bin/database-cli

WORKDIR /40scoreboard

COPY --from=production-deps /40scoreboard/node_modules /40scoreboard/node_modules
COPY --from=build /40scoreboard/node_modules/.prisma /40scoreboard/node_modules/.prisma

COPY --from=build /40scoreboard/build /40scoreboard/build
COPY --from=build /40scoreboard/public /40scoreboard/public
ADD . .

CMD ["npm", "start"]