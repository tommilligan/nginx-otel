# This file implements the `.github/workflows/ubuntu.yml` github action CI check
# as an environment agnostic docker container.
#
# This allows it to be used for local testing on a developer's machine.
#
# This file is not automatically updated, and may drift out of sync with CI.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y cmake libc-ares-dev \
        git curl jq python3-pip \
        build-essential libssl-dev libpcre3-dev zlib1g-dev

# Checkout nginx
RUN git clone https://github.com/nginx/nginx.git /nginx

# Build nginx
RUN cd /nginx && \
    auto/configure --with-compat --with-debug --with-http_ssl_module \
                   --with-http_v2_module --with-http_v3_module && \
    make -j $(nproc)

# Download otelcol
RUN LATEST=open-telemetry/opentelemetry-collector-releases/releases/latest && \
    TAG=$(curl -s https://api.github.com/repos/${LATEST} | jq -r .tag_name) && \
    curl -sLo - https://github.com/${LATEST}/download/otelcol_${TAG#v}_linux_amd64.tar.gz | tar -xzv

# Install test dependencies
RUN pip install -r tests/requirements.txt

# Copy module source
WORKDIR /ngx-otel
COPY . .

# Build module
RUN mkdir build && \
    cd build && \
    cmake -DNGX_OTEL_NGINX_BUILD_DIR=/nginx/objs \
          -DNGX_OTEL_DEV=ON .. && \
    make -j $(nproc)

CMD pytest tests --maxfail=10 --nginx=/nginx/objs/nginx \
                 --module=build/ngx_otel_module.so --otelcol=./otelcol
