# syntax=docker/dockerfile:1

# This Dockerfile is designed for production. Vite bakes VITE_* env vars into the
# static bundle at build time (import.meta.env), so they must be passed as build
# args, not container runtime env vars:
#
#   docker build \
#     --build-arg VITE_API_BASE_URL=https://<alb-dns>/api \
#     --build-arg VITE_CABLE_URL=wss://<nlb-dns>/cable \
#     -t frontend .

ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

ARG VITE_API_BASE_URL
ARG VITE_CABLE_URL
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL} \
    VITE_CABLE_URL=${VITE_CABLE_URL}

RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 5173
