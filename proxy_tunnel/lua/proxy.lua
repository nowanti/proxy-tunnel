local ipairs, tonumber, tostring, type = ipairs, tonumber, tostring, type
local log, ERR = ngx.log, ngx.ERR
local comm = require("lua.comm")
local cjson = require "cjson"

local _M = {
    _VERSION = '0.1.0',
}

local mt = { __index = _M }

local key_proxys = "proxy_tunnel:proxys"
local key_last_fetch = "proxy_tunnel:last_fetch"
local key_recent_visits = "proxy_tunnel:recent_visits"
-- 配置代理获取
local proxy_url = os.getenv("PROXY_URL")
if proxy_url==nil then
    log(ERR,"failed: PROXY_URL is nil, please configure it first.")
    os.execute("/usr/local/openresty/bin/openresty -s stop -p /app")
end
local proxy_check_url = os.getenv("PROXY_CHECK_URL")
local proxy_check_keywords = os.getenv("PROXY_CHECK_KEYWORDS")
-- -------------------------------------
local timer_delay = 5  --定时器周期
local fetch_cycle = 40 --代理更新周期
local visit_time_limit = 60 --代理最近访问时间范围
local fetch_num_limit = 10 -- 每次最大提取代理数
-- -------------------------------------
local function is_need_fetch(rds)
    ---检查上次访问时间距今多久了，超过周期则继续往下执行
    local res, err
    res, err = rds:get(key_last_fetch)
    if err then log(ERR,"failed: redis:get(key_last_fetch): ", err); end
    res = tonumber(res) or 0  -- 处理redis该值为空的情况
    if ngx.time()-res<fetch_cycle then return 0 end  -- 周期内已提取过，返回
    -------------------------------------
    ---获取代理最近访问情况
    local max = ngx.time()
    res, err = rds:zrangebyscore(key_recent_visits, max-visit_time_limit, max)
    if err then log(ERR,"failed: redis:get(key_last_fetch): ", err); end
    --log(ERR,"key_recent : ", cjson.encode(res), " ", cjson.encode(err))
    if not res then return 0 end --没有需求就返回了，避免浪费

    ---计算代理需求量
    return #res<=fetch_num_limit and #res or fetch_num_limit
end

local function proxy_check(proxy_ip)
    -- log(ERR, "proxy_check: ", proxy_ip, " | ", proxy_check_keywords, " | ", proxy_check_url)
    -- 检测代理是否可用
    local httpc = require("resty.http").new()
    httpc:set_timeout(5000)
    httpc:set_proxy_options({http_proxy = proxy_ip})
    local res, err = httpc:request_uri(proxy_check_url, {method = "GET", ssl_verify = false})
    -- log(ERR,"httpc:request_uri: ", res.body, " | ", err);
    log(ERR, proxy_ip, " | ", proxy_check_url, " | ", proxy_check_keywords, " | ", string.find(res.body, proxy_check_keywords))
    -- 检测返回结果是否包含关键字
    if res and res.body and string.find(res.body, proxy_check_keywords) then
        return true
    else
        return false
    end
end

local function proxy_fetch(demand)
    ---获取代理
    local url = string.format(proxy_url, demand)
    --log(ERR,"string.format: ", demand, " | ", proxy_url, " | ", url);
    local httpc = require("resty.http").new()
    httpc:set_timeout(5000)
    --httpc:set_proxy_options({http_proxy = proxy})  -- local proxy = "http://"..args.host..":"..args.port
    local res, err = httpc:request_uri(url, {method = "GET"})
    if not res or not res.body then return log(ERR,"failed: fetch_proxy: ", cjson.encode(err)) end
    --res={body="42.85.107.206:35413\r\n114.233.136.139:61321\r\n106.116.81.217:59298"}
    log(ERR,"httpc:request_uri: ", res.body, " | ", err);
    local ips = comm.str_split(res.body, "\r\n")
    ---添加代理获取时间
    local to_add = {}
    for i, v in ipairs(ips) do
        if proxy_check_url==nil or proxy_check(v) then
            table.insert(to_add, v)
            table.insert(to_add, ngx.time())
        end
    end
    return #ips, to_add
end

local function proxy_update()
    local rds, res, err
    rds, err= require("lua.redis").new()
    if err then return log(ERR,"failed: redis:new: ", err); end

    local demand = is_need_fetch(rds)
    if demand==0 then return end
    local fetched, to_add = proxy_fetch(demand)
    log(ERR,"proxy_fetch: fetched/useful: ", fetched, "/", #to_add/2, " | ", type(to_add), " | ", table.unpack(to_add));
    if type(to_add)~="table" or (#to_add/2)==0 then return end

    rds:del(key_proxys)
    res, err = rds:hset(key_proxys, table.unpack(to_add))
    log(ERR, "rds:hset: to_add : ", #to_add/2, " result : ", res, " ", err)
    rds:set(key_last_fetch, ngx.time()) --更新最后提取时间
end

local function proxy_update_handler(premature)
    if premature then return end
    proxy_update()
    -------------------------------------
--     ---重新启动timer
--     local ok, err = ngx.timer.at(0, proxy_update_handler)
--     if not ok then log(ERR, "failed to create timer: ", err) end
end
-- -------------------------------------
local port_random = 30100
local port_fixed_min = 30101
local port_fixed_max = 30200
local function set_proxy (host, port)
    ngx.ctx.proxy_host = host or "127.0.0.1"
    ngx.ctx.proxy_port = tonumber(port) or 502
end

-- 计算索引
local function calc_proxy_index (port_request, proxy_num)
    if port_fixed_min <= port_request and port_request <= port_fixed_max then
        return port_request % proxy_num + 1
    else
        math.randomseed(tostring(ngx.now()*1000):reverse():sub(1, 6))
        return math.random(proxy_num)
    end
end

-- 执行阶段 ----------
function _M.init_worker_by()
    if ngx.worker.id() == 0 then
        ngx.timer.every(timer_delay, proxy_update_handler)
    end
end

function _M.preread_by()
    -- set_proxy(nil, 502) -- 默认在 nginx.conf 中已配置为 127.0.0.1:502

    --local iputils = require("resty.iputils")
    --if not iputils.ip_in_cidrs(ngx.var.remote_addr, whitelist) then
    --  return set_proxy(nil, 403)
    --end

    local port_request = tonumber(ngx.var.server_port)

    local rds, res, err
    rds, res, err = require("lua.redis").new()
    if err then return log(ERR,"failed: redis:new: ", err) end
    -- 更新最近访问记录
    res, err = rds:zadd(key_recent_visits, ngx.time(), tostring(port_request))
    if not res then return log(ERR,"failed: redis:zadd: ", err) end
    -- 获取代理
    res, err = rds:hkeys(key_proxys)
    log(ERR,"rds:hkeys: ",type(res), ", ", cjson.encode(res), ", ", #res, ", ", err)
    if not res or #res==0 then return log(ERR,"failed: res num: ", #res, ", ", err) end
    local idx = calc_proxy_index(port_request,#res)
    local proxy = comm.str_split(res[idx], ":")
    log(ERR,"preread_by: ", idx, ", ", cjson.encode(proxy))
    rds:hset(key_ports, tostring(port_request), res[idx])

    set_proxy(proxy[1], proxy[2])
end

function _M.balancer_by()
    local host = ngx.ctx.proxy_host
    local port = ngx.ctx.proxy_port
    log(ERR,"balancer_by: ", host, ", ", port)
    if host~=nil and port~=nil then
        -- 初始化balancer
        local balancer = require "ngx.balancer"
        if host == "127.0.0.1" then ngx.exit(port); end
        -- 设置 balancer
        local ok, err = balancer.set_current_peer(host, port)
        if not ok then
            ngx.log(ngx.ERR, string.format("failed: balancer.set_current_peer: %s:%s %s", host, port, err))
        end;
    end
end

return _M