local _M = {}

local host = os.getenv("REDIS_HOST")
local port = os.getenv("REDIS_PORT")
local db = os.getenv("REDIS_DB")
local password = os.getenv("REDIS_PASSWORD")

--ngx.log(ngx.ERR, "redis", host, port, db, password)

if host == nil then
    local f = io.open('/app/.env', "r")
    if f ~= nil then
        local content = f:read("*all")
        f:close()
        _, _, host = string.find(content, "%sREDIS_HOST=([^%s]+)")
        _, _, port = string.find(content, "%sREDIS_PORT=([^%s]+)")
        _, _, db = string.find(content, "%sREDIS_DB=([^%s]+)")
        if db == nil then
            _, _, db = string.find(content, "%sREDIS_DATABASE=([^%s]+)")
        end
        _, _, password = string.find(content, "%REDIS_PASSWORD=([^%s]+)")
    end
end

host = host == nil and '127.0.0.1' or host
port = port == nil and 6379 or tonumber(port)
db = db == nil and 0 or tonumber(db)

function _M.new(opts)
    opts = opts or {}
    if (type(opts) ~= "table") then
        return nil, "opts must be a table"
    end

    host = opts['host'] and opts['host'] or host
    port = opts['port'] and opts['port'] or port
    db = opts['db'] and opts['db'] or db
    password = opts['password'] and opts['password'] or password
    --ngx.log(ngx.ERR, "redis", ", ", host, ", ", port, ", ", db, ", ", password)

    -- 依赖库
    local redis = require "resty.redis-util"
    -- 初始化
    local rds, err = redis:new({
        host = host,
        port = port,
        db_index = db,
        password = password,
        timeout = 10000,
        keepalive = 60000,
        pool_size = ngx.worker.count()
    });
    return rds, err
end

return _M