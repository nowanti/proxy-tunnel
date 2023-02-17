local _M = {}

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
    if not res or not res.body then return nil end
    return res.body
end

return _M