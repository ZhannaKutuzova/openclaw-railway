FROM node:22-bookworm@sha256:cd7bcd2e7a1e6f72052feb023c7f6b722205d3fcab7bbcbd2d1bfdab10b1e935

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app
RUN chown node:node /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Install ffmpeg for voice message audio conversion (OGG/OPUS)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

USER node
RUN pnpm install --frozen-lockfile

USER root
ARG OPENCLAW_INSTALL_BROWSER=""
RUN if [ -n "$OPENCLAW_INSTALL_BROWSER" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
      mkdir -p /home/node/.cache/ms-playwright && \
      PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
      node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
      chown -R node:node /home/node/.cache/ms-playwright && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

USER node
COPY --chown=node:node . .
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

USER node

RUN mkdir -p /home/node/.openclaw/workspace && \
    echo '{"gateway":{"bind":"lan","auth":{"mode":"token"},"controlUi":{"dangerouslyAllowHostHeaderOriginFallback":true,"dangerouslyDisableDeviceAuth":true,"allowInsecureAuth":true}},"agents":{"defaults":{"model":"anthropic/claude-sonnet-4-6"}},"channels":{"telegram":{"dmPolicy":"open","allowFrom":["*"]},"discord":{"dmPolicy":"open","allowFrom":["*"]},"whatsapp":{"dmPolicy":"open","allowFrom":["*"]}}}' \
    > /home/node/.openclaw/openclaw.json && \
    printf '#!/bin/sh\nset -e\nif [ -n "$CLAW_KNOWLEDGE_BASE" ]; then\n  printf "%%s" "$CLAW_KNOWLEDGE_BASE" > /home/node/.openclaw/workspace/IDENTITY.md\nfi\nnode openclaw.mjs doctor --fix 2>/dev/null || true\nexec node openclaw.mjs gateway --allow-unconfigured --bind lan\n' \
    > /home/node/.openclaw/entrypoint.sh && \
    chmod +x /home/node/.openclaw/entrypoint.sh

CMD ["/home/node/.openclaw/entrypoint.sh"]