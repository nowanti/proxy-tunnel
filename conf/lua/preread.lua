local set_proxy=function (host,port)
    ngx.ctx.proxy_host = host or "127.0.0.1"
    ngx.ctx.proxy_port = port or 502
    return nil
end

local iputils = require("resty.iputils")
if not iputils.ip_in_cidrs(ngx.var.remote_addr, whitelist) then
  return set_proxy(nil, 403)
end

----------------------------------------
-- 定义常量
local port_request = tonumber(ngx.var.server_port)
local port_random = 30100
local port_fixed_min = 30101
local port_fixed_max = 30200
-- 配置Redis
local redis_host = "127.0.0.1"
local redis_port = 30001
local redis_pass = "6T38Kky3NAokxdCj5zrxKj2FtUfNQJzd"
local key_proxy = "proxy_tunnel:proxys"
local key_recent = "proxy_tunnel:recent"
local key_ports = "proxy_tunnel:ports"
----------------------------------------
local redis_i = require "redis.iresty"
----------------------------------------
-- 创建实例
local redis = redis_i:new({db_host=redis_host, db_port=redis_port})
-- 验证密码，如果没有密码，移除下面这一行
local res, err = redis:auth(redis_pass)
if not res then ngx.log(ngx.ERR,"redis:auth error : ", err); ngx.ctx.proxy_port = 502; return end
-- 更新最近访问记录
local res, err = redis:zadd(key_recent, ngx.time(), tostring(port_request))
if not res then ngx.log(ngx.ERR,"redis:zadd error : ", err); ngx.ctx.proxy_port = 502; return end

-- 获取代理
local res, err = redis:hkeys(key_proxy)
if not res then
    ngx.log(ngx.ERR,"res num error : ", err)
    ngx.ctx.proxy_port = 502; return
end
-- 计算索引
local idx
if port_request == port_random then
    math.randomseed(tostring(ngx.now()*1000):reverse():sub(1, 6))
    idx = math.random(#res)
elseif port_fixed_min <= port_request and port_request <= port_fixed_max then
    idx = port_request % #res + 1
else
    ngx.ctx.proxy_port = 502; return
end
--ngx.log(ngx.ERR,"port = ", port_request, ", idx = ", idx);
-- 设置代理
local proxy = res[idx]
local colon_index = string.find(proxy, ":")
if colon_index==nil then ngx.ctx.proxy_port = 502; return end
local proxy_ip = string.sub(proxy, 1, colon_index - 1)
local proxy_port = string.sub(proxy, colon_index + 1)
--ngx.log(ngx.ERR, "idx = ", idx, ", ip = ", proxy_ip, ":", proxy_port);
local res, err = redis:hset(key_ports, tostring(port_request), proxy)
if not res then ngx.log(ngx.ERR,"redis:hset save port with proxy error : ", err); ngx.ctx.proxy_port = 502; return end

ngx.ctx.proxy_host = proxy_ip
ngx.ctx.proxy_port = proxy_port
