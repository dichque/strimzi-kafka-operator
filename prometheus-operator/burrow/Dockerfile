FROM golang:alpine
ENV CGO_ENABLED 0
RUN apk add --update bash curl git && apk add ca-certificates wget && update-ca-certificates && rm -rf /var/cache/apk/*
RUN go get github.com/linkedin/Burrow \
    github.com/golang/dep/cmd/dep
WORKDIR $GOPATH/src/github.com/linkedin/Burrow
RUN dep ensure && go install && mkdir -p /etc/burrow/
ADD ./ /etc/burrow/
RUN chmod +x /etc/burrow/startup.sh /etc/burrow/uid_entrypoint

RUN chmod -R u+x /etc/burrow && \
    chgrp -R 0 /etc/burrow && \
    chmod -R g=u /etc/burrow /etc/passwd

### Containers should NOT run as root as a good practice
USER 10001

ENTRYPOINT [ "/etc/burrow/uid_entrypoint" ]
WORKDIR /etc/burrow/
CMD ["/etc/burrow/startup.sh"]
