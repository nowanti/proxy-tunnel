# Proxy-Tunnel 隧道代理

## 功能特点

[-] 代理自动更新，按需提取（每5秒统计最近60s内的使用量，计算提取数，每40s更新一次ip）

[-] 隧道转发模式，使用方便

[-] 支持使用随机或固定的IP

[-] 动态白名单定期自动更新

## 端口范围

> 根据客户端请求的服务器的端口 ，确定是随机 还是固定 计算索引：每次获取全部IP，根据类型分别计算索引

30000 http

30100 stream 隧道代理，随机模式

30101~30200 stream 隧道代理，端口映射

## 使用例子

1. 部署：参考 `docker-compose.yml` 文件部署服务，并在防火墙（本地/云）开放相应端口
2. 加白：在 `redis` 的 `proxy_tunnel:white_ips` 中添加自己当前机器的ip
3. 验证：执行 `curl -v -x http://PROXY_TUNNEL_SERVER_IP:30100 http://httpbin.org/ip`