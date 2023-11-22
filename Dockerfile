FROM alpine:3.18
ARG action=create
RUN apk add -u curl jq
COPY ./scripts/${action}.sh /acorn/scripts/render.sh
ENTRYPOINT ["/acorn/scripts/render.sh"]