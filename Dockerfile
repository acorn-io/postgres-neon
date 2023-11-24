FROM alpine:3.18
ARG action=create
RUN apk add -u curl jq postgresql-client
COPY ./scripts/${action}.sh /acorn/scripts/render.sh
ENTRYPOINT ["/acorn/scripts/render.sh"]