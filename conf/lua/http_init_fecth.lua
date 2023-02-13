-- 辅助函数定义
local str_split = function (str, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end
    local start = 1
    local tab = {}
    while true do
        local pos = string.find(str, delim, start, true)
        if not pos then
            break
        end
        table.insert(tab, string.sub(str, start, pos - 1))
        start = pos + string.len(delim)
    end
    table.insert(tab, string.sub(str, start))
    return tab
end
local has_value = function (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end
-- -------------------------------------
-- 配置代理获取
local proxy_url = "http://service.ipzan.com/core-extract?no=20211021114537654079&secret=1d2gcqqo8&num=%d&minute=1&format=txt&area=all&protocol=1&repeat=1&pool=ordinary"
-- -------------------------------------
-- 配置Redis
local redis_host = "127.0.0.1"
local redis_port = 30001
local redis_pass = "6T38Kky3NAokxdCj5zrxKj2FtUfNQJzd"
local key_proxy = "proxy_tunnel:proxys"
local key_last = "proxy_tunnel:lastfetch"
local key_recent = "proxy_tunnel:recent"
-- -------------------------------------
local timer_delay = 5  --定时器周期
local fetch_cycle = 40 --代理更新周期
local recent_range = 60 --代理最近访问时间范围
local proxy_max = 5 -- 每次最大提取代理数
local log = ngx.log
local ERR = ngx.ERR
local check, check_point, check_mapping

-- 这个是做映射方式，周期性获取并更新，不与端口对应，直接映射
check_mapping = function(premature)
    if premature then return end
    -- -------------------------------------
    local redis_i = require "redis.iresty"
    local cjson = require "cjson"
    -- -------------------------------------
    -- 创建实例
    local redis = redis_i:new({db_host=redis_host, db_port=redis_port})
    -- 验证密码，如果没有密码，移除下面这一行
    local res, err = redis:auth(redis_pass)
    if not res then return log(ERR,"redis:auth error : ", err) end
    -------------------------------------
    ---检查上次访问时间距今多久了，超过周期则继续往下执行
    res, err = redis:get(key_last)
    if err then return end
    res = tonumber(res) or 0  -- 处理redis该值为空的情况
    if ngx.time()-res<fetch_cycle then return end --log(ERR,"not yet time for the next fetch cycle or error: ", err) end
    -------------------------------------
    ---获取代理最近访问情况
    local max = ngx.time()
    res, err = redis:zrangebyscore(key_recent, max-recent_range, max)
    --log(ERR,"key_recent : ", cjson.encode(res), " ", cjson.encode(err))
    if not res then return end --log(ERR,"no recent visits or error: ", err); end --没有需求就返回了，避免浪费
    ---确定代理需求量并设置链接
    local num = #res<=proxy_max and #res or proxy_max
    local url = string.format(proxy_url, num) --; log(ERR,"proxy_url : ", url)
    -------------------------------------
    ---获取代理
    local httpc = require("resty.http").new()
    httpc:set_timeout(5000)
    --httpc:set_proxy_options({http_proxy = proxy})  -- local proxy = "http://"..args.host..":"..args.port
    res, err = httpc:request_uri(url, {method = "GET"})
    if not res or not res.body then log(ERR,"proxy fetch error : ", cjson.encode(err)) return end
    --res={body="42.85.107.206:35413\r\n114.233.136.139:61321\r\n106.116.81.217:59298"}
    local live_ips = str_split(res.body, "\r\n")
    --log(ERR,"live_ips : ", cjson.encode(live_ips))
    -------------------------------------
    ---获取已有代理
    local pool_ips, err = redis:hkeys(key_proxy)
    --log(ERR,"res data : ", cjson.encode(pool_ips), " ", cjson.encode(err))
    pool_ips = type(pool_ips)=="table" and pool_ips or {}  -- 处理redis该值为空的情况
    -------------------------------------
    ---删除不存在的
    local to_del = {}
    for i,v in ipairs(pool_ips) do
        if not has_value(live_ips, v) then
            table.insert(to_del, v)
        end
    end
    --log(ERR,"to_del : ", #to_del, " ", cjson.encode(to_del))
    if #to_del>0 then redis:hdel(key_proxy, table.unpack(to_del)) end
    -------------------------------------
    ---更新代理数据
    local to_add = {}
    for i, v in ipairs(live_ips) do
        if not has_value(pool_ips, v) then
            table.insert(to_add, v)
            table.insert(to_add, ngx.time())
        end
    end
    --log(ERR,"to_add : ", #to_add, " ", cjson.encode(to_add))
    res, err = redis:hset(key_proxy, table.unpack(to_add))
    log(ERR,"to_add : ", #to_add/2, " result : ", cjson.encode(res), " ", cjson.encode(err))
    -------------------------------------
    redis:set(key_last, ngx.time()) --更新最后提取时间

end

check = function(premature, func)
    if premature then return end
    func()
    -------------------------------------
    ---重新启动timer
    local ok, err = ngx.timer.at(timer_delay, check, func)
    if not ok then log(ERR, "failed to create timer: ", err) end
end

if 0 == ngx.worker.id() then
    local ok, err = ngx.timer.at(timer_delay, check, check_mapping)
    if not ok then
        log(ERR, "failed to create timer: ", err)
        return
    end
end



