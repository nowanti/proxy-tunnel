FROM openresty/openresty:1.21.4.1-5-jammy
WORKDIR /app

RUN opm get ledgetech/lua-resty-http && \
    opm get anjia0532/lua-resty-redis-util &&  \
    opm get hamishforbes/lua-resty-iputils

COPY proxy_tunnel .

CMD /bin/sh -c "mkdir -p /app/logs && openresty -p /app"