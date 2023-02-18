local _M = {}

local function tostrings(var)
    return var == nil and '' or tostring(var)
end
_M.tostrings = tostrings

local function tonumbers(var, base)
    local ret = tonumber(var, base)
    return ret == nil and 0 or ret
end
_M.tonumbers = tonumbers

local function table_print(tab, hasKey, sep)
    if type(tab) ~= "table" then
        return tostrings(tab)
    end

    hasKey = hasKey == nil and true or hasKey
    sep = sep or ","
    local str = ""
    for k, v in pairs(tab) do
        k = hasKey and (type(k) == "number" and "[" .. k .. "]" or k) .. "=" or ""
        if type(v) == "table" then
            str = str .. k .. table_print(v, hasKey, sep) .. sep
        elseif type(v) == "string" then
            str = str .. k .. "'" .. v .. "'" .. sep
        else
            str = str .. k .. tostrings(v) .. sep
        end
    end

    str = "{" .. string.sub(str, 1, #str - #sep) .. "}"
    return str
end
_M.table_print = table_print

-- 获取当前是在哪个模块中
function _M.get_module_name()
    local phases = ngx.get_phase()
    if phases["access"] then
        return "http"
    else
        return "stream"
    end

end

-- 取以 模块名称 和 下划线 为前缀的 ngx.shared 变量
function _M.module_shared_get(name)
    return ngx.shared:get(_M.get_module_name() .. "_" .. name)
end

function _M.str_split(str, delim)
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

function _M.in_array(value, list)
    if type(list) == 'table' then
        for idx, item in ipairs(list) do
            if item == value then
                return true
            end
        end
    end
    return false
end

function _M.get_wlan_ip()
    local httpc = require("resty.http").new()
    httpc.set_timeout(5000)

    local url = "http://myip.ipip.net/s"
    local res, err = httpc.requst_uri(url, { method = "GET" })
    if not res or not res.body then
        return nil
    end
    return res.body
end

return _M