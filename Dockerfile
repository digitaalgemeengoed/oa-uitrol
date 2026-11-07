# Bouwt alle onderdelen van het prototype uit de repositories naast elkaar
# in ./bron (zie haal-op.sh). Eén bestand, drie doelen:
#   --target platform        opendop-mini (server, migratie en worker)
#   --target diensten        oa-services
#   --target integratielaag  oa-integratielaag met paneel en demo-werkomgeving

FROM node:22-alpine AS bouw
WORKDIR /bron
COPY package.json package-lock.json ./
COPY oa-contract/package.json oa-contract/
COPY opendop-mini/package.json opendop-mini/
COPY oa-services/package.json oa-services/
COPY oa-kern/package.json oa-kern/
COPY oa-paneel/package.json oa-paneel/
COPY oa-adapters/package.json oa-adapters/
COPY oa-integratielaag/package.json oa-integratielaag/
RUN npm ci --no-audit --no-fund
COPY . .
# Volgorde telt: de werkomgeving moet in public/ staan vóór next build.
RUN npm run build -w oa-contract \
 && npm run build -w oa-kern \
 && npm run build -w opendop-mini \
 && npm run build -w oa-services \
 && npm run build -w oa-paneel \
 && npm run build -w oa-adapters \
 && cd oa-integratielaag && node scripts/werkomgeving.mjs ../oa-adapters/dist/werkomgeving && npx next build

# --- Platform --------------------------------------------------------------
FROM node:22-alpine AS platform
ENV NODE_ENV=production
WORKDIR /app
COPY --from=bouw /bron/package.json ./
COPY --from=bouw /bron/node_modules ./node_modules
COPY --from=bouw /bron/oa-contract ./oa-contract
COPY --from=bouw /bron/opendop-mini ./opendop-mini
WORKDIR /app/opendop-mini
USER node
EXPOSE 4100
CMD ["node", "dist/index.js", "server"]

# --- Assistent-services ----------------------------------------------------
FROM node:22-alpine AS diensten
ENV NODE_ENV=production
WORKDIR /app
COPY --from=bouw /bron/package.json ./
COPY --from=bouw /bron/node_modules ./node_modules
COPY --from=bouw /bron/oa-contract ./oa-contract
COPY --from=bouw /bron/oa-services ./oa-services
WORKDIR /app/oa-services
USER node
EXPOSE 4200
CMD ["node", "dist/index.js"]

# --- Integratielaag --------------------------------------------------------
FROM node:22-alpine AS integratielaag
ENV NODE_ENV=production HOSTNAME=0.0.0.0 PORT=3000
WORKDIR /app
COPY --from=bouw /bron/oa-integratielaag/.next/standalone ./
COPY --from=bouw /bron/oa-integratielaag/.next/static ./oa-integratielaag/.next/static
COPY --from=bouw /bron/oa-integratielaag/public ./oa-integratielaag/public
USER node
EXPOSE 3000
CMD ["node", "oa-integratielaag/server.js"]
