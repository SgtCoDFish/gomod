# Gomod

A simple go module proxy, currently designed to be run behind a reverse proxy.

This is intentionally minimal for my own use cases, but it works well.

## Example Nginx Reverse Proxy Config

This assumes letsencrypt certs are available in `/etc/ssl` and safe dhparams in `/etc/ssl/dhparam.pem`. Would be better with TLS 1.3!

```nginx
# vim: filetype=nginx

upstream gomod {
	server 127.0.0.1:14115;
}

server {
	server_name gomod.example.com;

	listen      443 ssl;
	autoindex   on;

	proxy_http_version 1.1;

	ssl_protocols TLSv1.2;
	ssl_prefer_server_ciphers on;
	ssl_session_timeout 1d;
	ssl_session_cache shared:SSL:50m;
	ssl_session_tickets off;

	ssl_ciphers "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256";

	add_header X-Frame-Options "SAMEORIGIN";
	add_header X-Content-Type-Options "nosniff";
	add_header X-XSS-Protection "1; mode=block";

	# uncomment if you use HSTS preload
	# add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";

	ssl_certificate /etc/ssl/fullchain.pem;
	ssl_certificate_key /etc/ssl/privkey.pem;

	# uncomment if you're using safe dhparams
	# ssl_dhparam /etc/ssl/dhparam.pem;

	location ~ / {
		proxy_pass http://gomod;
	}
}
```
