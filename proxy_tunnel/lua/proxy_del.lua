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
local res, err = nil, nil
-- 创建实例
local redis = redis_i:new({db_host=redis_host, db_port=redis_port})
-- 验证密码，如果没有密码，移除下面这一行
res, err = redis:auth(redis_pass)
if not res then ngx.log(ngx.ERR,"redis:auth error : ", err); return ngx.exit(502) end
if type(ngx.var.arg_port)=='string' and #ngx.var.arg_port>0 then
    res, err = redis:hget(key_ports, ngx.var.arg_port)
    if not res then ngx.log(ngx.ERR,"redis:hget port error : ", ngx.var.arg_port, ', ',  err); return ngx.exit(502) end
    --ngx.say("arg_port: ", ngx.var.arg_port, ', hget: ', type(res), ', ', res)
    res, err = redis:hdel(key_proxy, res)
    if not res then ngx.log(ngx.ERR,"redis:hdel error : ", ngx.var.arg_port , ', ',  proxy , ', ', err); return ngx.exit(502) end
end
ngx.say("ok")
