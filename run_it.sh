IMAGE=leandrocarneiro/openresty
docker rm -vf openresty ;
docker run -d --name=openresty --rm -e UPSTREAM_SITE="http://httpbin.org/anything/env" -e DNS_WHITELIST='172.17.0.1.nip.io,192.168.2.195.nip.io' -p 80:80 -v ${PWD}/proxy.conf:/etc/nginx/conf.d/default.conf -v ${PWD}/dns.lua:/etc/nginx/conf.d/dns.lua -v ${PWD}/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf ${IMAGE}; 
http GET localhost
echo -e '\n'
docker logs openresty
