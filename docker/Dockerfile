# Base image for orchestra's workers: OpenCode, claude, codex, grok and agy CLIs.
# Projects can extend it with <repo>/.orchestra/Dockerfile:
#   FROM orchestra-opencode
#   RUN apt-get update && apt-get install -y --no-install-recommends golang && rm -rf /var/lib/apt/lists/*
FROM node:22-bookworm

ARG OPENCODE_VERSION=latest
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-pip python3-venv ripgrep jq less \
 && rm -rf /var/lib/apt/lists/*
# OpenCode 2 ships through its own installer (not npm).
RUN if [ "$OPENCODE_VERSION" = latest ]; then curl -fsSL https://opencode.ai/v2/install | bash; \
    else curl -fsSL https://opencode.ai/v2/install | bash -s -- --version "$OPENCODE_VERSION"; fi \
 && install -m 755 /root/.opencode/bin/opencode /usr/local/bin/opencode \
 && rm -rf /root/.opencode \
 && opencode --version
# Native agent CLIs (vendor installers, checksum-verified). Installed as root, then copied to
# /usr/local/bin because workers run as the host uid with HOME=/home/oc.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && install -m 755 "$(readlink -f /root/.local/bin/claude)" /usr/local/bin/claude \
 && rm -rf /root/.local/share/claude /root/.local/bin/claude /root/.claude
# Codex ships on npm (a node launcher plus the native binary for this platform).
RUN npm install -g @openai/codex && codex --version
RUN curl -fsSL https://x.ai/cli/install.sh | bash \
 && for b in grok agent; do if [ -e /root/.grok/bin/$b ]; then install -m 755 "$(readlink -f /root/.grok/bin/$b)" /usr/local/bin/$b; fi; done \
 && rm -rf /root/.grok
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash \
 && install -m 755 "$(readlink -f /root/.local/bin/agy)" /usr/local/bin/agy \
 && rm -rf /root/.local/bin/agy /root/.cache/antigravity

# Runs as the host uid (docker run --user), so HOME and OpenCode's dirs must be writable by anyone.
RUN mkdir -p /home/oc/.local/share/opencode /home/oc/.cache /home/oc/.config /home/oc/.claude /home/oc/.codex /home/oc/.grok /home/oc/.gemini \
 && chmod -R 777 /home/oc \
 && git config --system safe.directory '*' \
 && git config --system user.name orchestra \
 && git config --system user.email orchestra@localhost

# CLAUDE_CONFIG_DIR keeps .claude.json inside the ~/.claude login volume.
ENV HOME=/home/oc TERM=dumb CLAUDE_CONFIG_DIR=/home/oc/.claude DISABLE_AUTOUPDATER=1
WORKDIR /home/oc
ENTRYPOINT []
