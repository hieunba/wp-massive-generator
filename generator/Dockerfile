FROM python:3.8.5-alpine3.12

ARG TERRAFORM_VERSION
ENV TERRAFORM_VERSION ${TERRAFORM_VERSION:-0.12.29}
ENV TERRAFORM_DOWNLOAD_URL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
ARG AWSCLI_VERSION
ENV AWSCLI_VERSION ${AWSCLI_VERSION:-1.18.115}

RUN set -ex; \
    apk -uv add --no-cache git groff jq less bash ncurses

RUN set -ex; \
    pip install awscli==$AWSCLI_VERSION

RUN set -ex; \
    wget -O terraform.zip $TERRAFORM_DOWNLOAD_URL \
    && unzip terraform.zip \
    && mv terraform /usr/local/bin \
    && chmod +x /usr/local/bin/terraform \
    && rm terraform.zip

COPY terraform/generator/ /app/generator

WORKDIR /app/generator

COPY entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/entrypoint.sh

COPY cmd.sh /cmd.sh

RUN chmod +x /cmd.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["/cmd.sh"]
