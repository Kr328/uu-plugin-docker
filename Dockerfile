FROM alpine:latest

RUN apk add --no-cache tini curl iproute2 iptables

RUN curl -s uudeck.com | sed 's/check_running$//g' | sed 's/systemctl/true/g' | sh

COPY init.sh /init.sh

RUN rm -rf /tmp/*

RUN chmod 700 /init.sh

VOLUME [ "/persist" ]

ENTRYPOINT [ "/sbin/tini", "/init.sh" ]
