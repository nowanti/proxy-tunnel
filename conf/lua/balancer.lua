if ngx.ctx.proxy_host~=nil and ngx.ctx.proxy_port~=nil then
    -- 初始化balancer
    local balancer = require "ngx.balancer"
    local host = ngx.ctx.proxy_host
    local port = ngx.ctx.proxy_port

    if host == "127.0.0.1" then
      ngx.exit(port)
    end

    -- 设置 balancer
    local ok, err = balancer.set_current_peer(host, port)
    if not ok then
        ngx.log(ngx.ERR, string.format("failed to set the peer: %s:%s %s", host, port, err))
    end;
end
