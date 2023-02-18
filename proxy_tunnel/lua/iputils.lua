-- 动态IP白名单，使用 redis，定期刷新名单
local log, ERR = ngx.log, ngx.ERR
local cjson = require "cjson"
local comm = require "lua.comm"

local _M = {
    _VERSION = '0.1.0',
}

local timer_delay = 60
local key_white_ips = "proxy_tunnel:white_ips"
local default_white_ips = {
    "127.0.0.1",
    "10.10.10.0/24",
    "192.168.0.0/16",
    "172.10.0.0/24",
    "172.18.0.0/24",
    "172.20.0.0/24",
}

local function ngx_shared_ips()
    return ngx.shared.stream_ips or ngx.shared.http_ips
end

local function reload_white_ips()
    local rds, res, err
    rds, err = require("lua.redis").new()
    if err then
        return log(ERR, "failed: redis:new: ", err);
    end

    res, err = rds:hkeys(key_white_ips)
    if err then
        return log(ERR, "failed: rds.hkeys(key_white_ips): ", err);
    end
    --log(ERR, ngx.worker.id(), ": white res: ", cjson.encode(res));

    local white_ips = (res and #res > 0) and res or default_white_ips
    --log(ERR, ngx.worker.id(), ": white_ips.redis: ", cjson.encode(white_ips));

    local iputils = require("resty.iputils")
    iputils.enable_lrucache()

    white_ips = cjson.encode(iputils.parse_cidrs(white_ips))
    --log(ERR, ngx.worker.id(), ": white_ips.cidr: ", white_ips);

    ngx_shared_ips():set("white", white_ips)

    return white_ips
end

local function reload_ips_hander(premature)
    if premature then
        return
    end
    reload_white_ips()
    -------------------------------------
    -- 重新启动timer
    local ok, err = ngx.timer.at(timer_delay, reload_ips_hander)
    if not ok then
        log(ERR, "failed to create timer: ", err)
    end
end

function _M.init_worker_by()
    if ngx.worker.id() == 0 then
        ngx.timer.at(0, reload_ips_hander)
    end
end

function _M.ip_in_white_ips()
    local white_ips = cjson.decode(ngx_shared_ips():get("white"))
    log(ERR, ngx.worker.id(), ": white_ips.cidr: ", cjson.encode(white_ips));

    local iputils = require("resty.iputils")
    if not iputils.ip_in_cidrs(ngx.var.remote_addr, white_ips) then
        if ngx.shared.stream_ips ~= nil then
            ngx.ctx.proxy_host = "127.0.0.1"
            ngx.ctx.proxy_port = 403
            return false
        else
            return ngx.exit(ngx.HTTP_FORBIDDEN)
        end
    end
    return true
end

return _M