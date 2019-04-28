local os_getenv = os.getenv
local split = require("ngx.re").split
local type=type
local confdns_whitelist = split(os_getenv("DNS_WHITELIST"),",") or { "172.17.0.1.nip.io", "127.0.0.1.nip.io" }

local mlcache       = require("resty.mlcache")
local cache, err = mlcache.new("dns-plugin", "dns_shared_dict", {
    lru_size = 20,  -- size of the L1 (Lua VM) cache
    ttl      = 120,    -- 120s ttl for hits
    neg_ttl  = 1,      -- 1s ttl for misses
})
if err then
    return error("failed to create the cache: " .. (err or "unknown"))
end


local resolver = require "resty.dns.resolver"
local r, err = resolver:new{
    nameservers = {"8.8.8.8", {"8.8.4.4", 53} },
    retrans = 5,    -- 5 retransmissions on receive timeout
    timeout = 2000, -- 2 sec
}

local ipairs=ipairs
local ngx_log=ngx.log
local ngx_ERR=ngx.ERR
local ngx_DEBUG=ngx.DEBUG
local ngx_exit=ngx.exit
local ngx_say=ngx.say
local table_concat=table.concat

if not r then
    ngx_say("failed to instantiate the resolver: ", err)
    return ngx_exit(500)
end


local function collect(value, table)
  local r=''
  local i=0
  for _, v in ipairs(table) do
    if (v[value]) then
      r = (r == '') and v[value] or table_concat({r , ',' , v[value]})
    end
  end
  return r
end


local function resolve_names(dns_name)
	ngx_log(ngx_DEBUG, '>>>>>>>>>> Put on cache: ' .. dns_name )
        local answers, err, tries = r:query(dns_name, nil, {})
        if not answers then
            ngx_say("failed to query the DNS server: ", err)
            ngx_say("retry historie:\n  ", table_concat(tries, "\n  "))
            return ngx_exit(500)
        end

        if answers.errcode then
            ngx_say("server returned error code: ", answers.errcode,
                    ": ", answers.errstr)
            return ngx_exit(500)
        end

	return answers, nil, answers[1].ttl
end


for _,dns_whitelist in ipairs(confdns_whitelist) do
	local answers, err = cache:get(dns_whitelist, nil, resolve_names, dns_whitelist)

	if answers then
  	  local ips=collect('address',answers)
  	  if ips:match(ngx.var.remote_addr) then
	    ngx.header["X-Granted-Access-By"] ="DNS"
	    return
	  end
        end

end

return ngx_exit(ngx.HTTP_FORBIDDEN)
