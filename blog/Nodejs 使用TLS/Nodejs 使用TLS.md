---
title: Nodejs使用TLS
date: 2022-01-31 10:22:00
tags:
---
CA机构的数字证书是整个TLS(SSL)协议的根证书，用于给服务器及客户端证书签名及验证其真伪。生成方法如下：

```sh
openssl genrsa -out ca-key.pem -des 1024
openssl req -new -key ca-key.pem -out ca-csr.pem
openssl x509 -req -days 3650 -in ca-csr.pem -signkey ca-key.pem -out ca-cert.pem
```
然后根据ca生成服务端证书：

```sh
openssl genrsa -out server-key.pem 1024
openssl req -new -key server-key.pem -out server-csr.pem
openssl x509 -req -days 730 -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -in server-csr.pem -out server-cert.pem
```

为了避免出错，请给每个证书一个唯一的通用名称．例如,将您的CA证书“Foo CA”命名,您的服务器证书是您的主机名称(在这种情况下为“localhost”),您的客户端将其名称(例如“Foo Client 1”)命名.

<!--more-->

下面是服务端程序：

```js
var tls = require('tls');
var fs = require('fs');
var options = {
        // This is necessary only if using the client certificate authentication.
        key: fs.readFileSync('server-key.pem'),
        cert: fs.readFileSync('server-cert.pem'),
        // This is necessary only if the client uses the self-signed certificate.
        //ca: [ fs.readFileSync('ca-cert.pem') ],
        requestCert: false,
        rejectUnauthorized: true
};
var server = tls.createServer(options, function(test) {
        console.log('server connected', test.authorized ? 'authorized' : 'unauthorized');
        test.write("welcome!\n");
        test.setEncoding('utf8');
        test.on('data', function(data) {
                console.log(data);
        });
        test.on('close', function() {
                console.log('client has closed');
                server.close();
        });
});
server.listen(2345, function() {
        console.log('server bound');
});
```

下面是客户端程序：

```js
var tls = require('tls');
var fs = require('fs');
var options = {
        host: 'localhost',
        port: 2345,
        // These are necessary only if using the server certificate authentication
        //key: fs.readFileSync('client-key.pem'),
        //cert: fs.readFileSync('client-cert.pem'),
        // This is necessary only if the server uses the self-signed certificate
        ca: [ fs.readFileSync('ca-cert.pem') ],
        rejectUnauthorized: true
};
var client = tls.connect(options, function() {
        console.log('client connected', client.authorized ? 'authorized' : 'unauthorized');
        process.stdin.setEncoding('utf8');
        process.stdin.on('readable', function() {
                var chunk = process.stdin.read();
                if (chunk !== null) {
                        client.write(chunk);
                }
        });

});
client.setEncoding('utf8');
client.on('data', function(data) {
        console.log(data);
});
client.write("happy new year!");
```

除了上面的做法外，还可以让服务端证书成为自签名的，也就是自己扮演ca．

```sh
openssl genrsa -out lts-key.pem -des 1024
openssl req -new -key lts-key.pem -out lts-csr.pem
openssl x509 -req -days 3650 -in lts-csr.pem -signkey lts-key.pem -out lts-cert.pem
```

那么，上面的客户端程序中的 ca-cert.pem 可以替换成上述的 lts-cert.pem．

删除密钥中的密码

openssl rsa -in lts.key -out lts.key.pem

说明：如果不删除密码，在应用加载的时候会出现输入密码进行验证的情况，不方便自动化部署。

参考：
<a href='https://blog.csdn.net/junehappylove/article/details/52288796'>数字证书原理,公钥私钥加密原理 - 因为这个太重要了</a>

<a href='https://nodejs.org/api/tls.html#tlsconnectoptions-callback'>Node.js v17.4.0 documentation</a>

<a href='https://blog.csdn.net/marujunyy/article/details/8477854'>Node.Js TLS(SSL) HTTPS双向验证</a>

<a href='https://blog.csdn.net/qq_21460229/article/details/104440053'>Nodejs使用TLS</a>