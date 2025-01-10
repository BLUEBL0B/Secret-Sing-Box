### General settings
First, you need to add your domain to your Cloudflare account and specify Cloudflare NS servers at your domain registrar.

Next, change the following settings in your Cloudflare account: 
1) SSL/TLS > Overview > Configure > Full
2) SSL/TLS > Edge Certificates > Minimum TLS Version > TLS 1.2
3) SSL/TLS > Edge Certificates > TLS 1.3 > Enable

### DNS Settings
Example of DNS records:

![dns-2](https://github.com/user-attachments/assets/a0be45a5-2013-48b7-a3f9-565a396b33bb)

For the setup option with TLS termination on NGINX and WebSocket or HTTPUpgrade transport, you can enable proxying of both records (this may require to disable ECH).

> [!IMPORTANT]
> If you already have an A record for this domain created for other purposes, then also create an A record for subdomain:
>
> A | sub | 98.76.54.32
>
> Instead of «sub», specify your subdomain and enter it in the script instead of your domain (e. g. sub.example.com).

### Getting Cloudflare API token
Overview > Get your API token > Create Token > Edit zone DNS (Use template)

Then specify the following settings:

![token](https://github.com/user-attachments/assets/7eecc898-923b-4cbc-97f7-fc3d45deb395)

Other settings can be left as is.

After receiving the token, you need to copy and save it, because it will only be shown once.

You can use an API key instead of a token, but this is less secure and not recommended.
