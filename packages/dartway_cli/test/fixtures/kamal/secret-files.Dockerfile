FROM docker:29.1.3-dind
RUN apk add --no-cache --upgrade openssh sudo coreutils
