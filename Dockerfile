FROM openresty/openresty:1.21.4.1-5-jammy-aarch64
WORKDIR /app
#WORKDIR .

# RUN
RUN opm get hamishforbes/lua-resty-iputils && opm get anjia0532/lua-resty-redis-util && opm get ledgetech/lua-resty-http

# COPY conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
# COPY lua /usr/local/openresty/nginx/lua
#COPY libs /usr/local/openresty/lualib
COPY conf .

CMD ["openresty", "-p", "/app"]