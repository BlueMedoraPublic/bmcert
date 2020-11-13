FROM golang:1.15 AS stage

WORKDIR /bmcert
ARG token
ARG addr
ARG url
ARG pki_url
ARG version
ENV VAULT_TOKEN=$token
ENV VAULT_ADDR=$addr
ENV VAULT_CERT_URL=$url
ENV VAULT_PKI_URL=$pki_url
ENV VAULT_SKIP_VERIFY=true

ADD . /bmcert

RUN \
    go get github.com/spf13/cobra && \
    go get github.com/BlueMedoraPublic/go-pkcs12 && \
    go get github.com/hashicorp/vault/sdk/helper/certutil && \
    go get github.com/mitchellh/go-homedir

RUN go test ./...

# build without cgo, we do not need it for bmcert
RUN env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bmcert
RUN env CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o bmcert-darwin

RUN apt-get update >> /dev/null && \
    apt-get install -y openssl zip >> /dev/null

# create and validate
RUN ./bmcert create --hostname test.subdomain.test.local --tls-skip-verify && \
    openssl x509 -in test.subdomain.test.local.pem -text -noout

RUN ./bmcert create --hostname test3.test.local --tls-skip-verify && \
    openssl x509 -in test3.test.local.pem -text -noout

RUN ./bmcert create --hostname test2.test.local --tls-skip-verify --format cert && \
    openssl x509 -in test2.test.local.crt -text -noout && \
    openssl rsa -in test2.test.local.key -check

RUN ./bmcert create --hostname test2.test.local --tls-skip-verify --format p12 --password password

# test force replace flag
RUN ./bmcert create -f --hostname test2.test.local --tls-skip-verify --format p12 --password password

# test cert expiration, current year and future year should not be equal
RUN \
    ./bmcert create --hostname test2.test.local --tls-skip-verify -f --ttl 12m && \
    CURRENT_YEAR=$(TZ=GMT date +"%c %Z" | awk '{print $5}') && \
    FUTURE_YEAR=$(openssl x509 -in test2.test.local.pem -text -noout -dates | grep notAfter | awk '{print $4}') && \
    if [ "$CURRENT_YEAR" = "$FUTURE_YEAR" ]; then exit 1; fi

# test cert expiration, current year and future year should be equal
# this requires ttl greater than
RUN \
    ./bmcert create --hostname test2.test.local --tls-skip-verify -f --ttl 1s && \
    CURRENT_YEAR=$(TZ=GMT date +"%c %Z" | awk '{print $5}') && \
    FUTURE_YEAR=$(openssl x509 -in test2.test.local.pem -text -noout -dates | grep notAfter | awk '{print $4}') && \
    if [ "$CURRENT_YEAR" != "$FUTURE_YEAR" ]; then exit 1; fi

# test ca command
RUN \
    ./bmcert ca --force --tls-skip-verify && \
    openssl x509 -in ca.crt -text -noout

# build the relese
#
RUN zip bmcert-v${version}-linux-amd64.zip bmcert
RUN mv bmcert-darwin bmcert && zip bmcert-v${version}-darwin-amd64.zip bmcert
RUN sha256sum bmcert-v${version}-linux-amd64.zip >> bmcert-v${version}.SHA256SUMS
RUN sha256sum bmcert-v${version}-darwin-amd64.zip >> bmcert-v${version}.SHA256SUMS
