FROM node:22-bookworm

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g openclaw@latest

USER node

RUN mkdir -p /home/node/.openclaw/workspace \
    /home/node/.openclaw/agents/main/sessions \
    /home/node/.openclaw/credentials

RUN echo '{"gateway":{"bind":"lan","trustedProxies":["100.64.0.0/10","10.0.0.0/8","172.16.0.0/12"],"auth":{"mode":"token"},"controlUi":{"dangerouslyAllowHostHeaderOriginFallback":true,"dangerouslyDisableDeviceAuth":true,"allowInsecureAuth":true}},"agents":{"defaults":{"model":"anthropic/claude-sonnet-4-6"}},"channels":{"telegram":{"dmPolicy":"open","allowFrom":["*"]},"discord":{"dmPolicy":"open","allowFrom":["*"]},"whatsapp":{"dmPolicy":"open","allowFrom":["*"]}}}' \
    > /home/node/.openclaw/openclaw.json

RUN printf '#!/bin/sh\nset -e\nif [ -n "$CLAW_KNOWLEDGE_BASE" ]; then\n  printf "%%s" "$CLAW_KNOWLEDGE_BASE" > /home/node/.openclaw/workspace/IDENTITY.md\nfi\nmkdir -p /home/node/.openclaw/agents/main/sessions /home/node/.openclaw/credentials\nif [ "$OPENCLAW_WHATSAPP_CLEAN" = "true" ]; then\n  echo "[entrypoint] Cleaning WhatsApp session data..."\n  rm -rf /home/node/.openclaw/credentials/whatsapp* /home/node/.openclaw/data/whatsapp* 2>/dev/null || true\nfi\nexec openclaw gateway --allow-unconfigured --bind lan\n' \
    > /home/node/.openclaw/entrypoint.sh && \
    chmod +x /home/node/.openclaw/entrypoint.sh

ENV NODE_ENV=production
EXPOSE 8080

CMD ["/home/node/.openclaw/entrypoint.sh"]