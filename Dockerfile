FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    jq \
    bash \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @google/gemini-cli@latest

RUN useradd -m -s /bin/bash gemini \
    && mkdir -p /var/run/sshd \
    && mkdir -p /opt/n8n-ai \
    && chown -R gemini:gemini /opt/n8n-ai \
    && chown -R gemini:gemini /home/gemini

COPY gemini_agent.sh /opt/n8n-ai/gemini_agent.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /opt/n8n-ai/gemini_agent.sh /entrypoint.sh \
    && chown gemini:gemini /opt/n8n-ai/gemini_agent.sh

EXPOSE 22

CMD ["/entrypoint.sh"]
