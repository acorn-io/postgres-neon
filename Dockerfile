FROM debian:trixie-slim
ARG action=create
RUN apt update && apt install -y curl jq postgresql-client
RUN curl -sL https://github.com/neondatabase/neonctl/releases/latest/download/neonctl-linux -o neonctl && chmod +x neonctl && mv neonctl /usr/local/bin
COPY ./scripts/${action}.sh /acorn/scripts/render.sh
ENTRYPOINT ["/acorn/scripts/render.sh"]