FROM ubuntu:18.04
RUN apt-get update \
    && apt-get install -y jq curl gnupg2 bc && apt-get -y upgrade \
    && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get install -y kubectl && apt-get autoremove -y
ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini /sbin/tini
RUN chmod +x /sbin/tini && mkdir -p /user/autoscaler && mkdir -p /app
ADD . /app

RUN useradd autoscaler --uid 9999 -M -U --home-dir /user/autoscaler
USER autoscaler
WORKDIR /user/autoscaler
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/bin/bash", "-c", "/app/autoscale.sh"]
