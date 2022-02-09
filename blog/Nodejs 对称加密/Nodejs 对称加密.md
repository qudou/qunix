---
title: Nodejs对称加密
date: 2022-02-09 16:41:00
tags:
---

使用 aes 加密解密。

```js
// 加密, key 加密key, iv 向量, data 需要加密的数据
var encrypt = function (key, iv, data) {
    var cipher = crypto.createCipheriv('aes-128-cbc', key, iv);
    var crypted = cipher.update(data, 'utf8', 'binary');
    crypted += cipher.final('binary');
    crypted = Buffer.from(crypted, 'binary').toString('base64');
    return crypted;
};
```
<!--more-->
```js
// 解密, key 解密key, iv 向量, crypted 密文
var decrypt = function (key, iv, crypted) {
    crypted = Buffer.from(crypted, 'base64').toString('binary');
    var decipher = crypto.createDecipheriv('aes-128-cbc', key, iv);
    var decoded = decipher.update(crypted, 'binary', 'utf8');
    decoded += decipher.final('utf8');
    return decoded;
};
```
使用示例：
```js
var key = '751f621ea5c8f930';
console.log('key:', key.toString('hex'));
var iv = '2624750004598718';
console.log('iv:', iv);
var data = "Hello, nodejs.";
console.log("data", data);
var crypted = encrypt(key, iv, data);
console.log("encrypted:", crypted);
var dec = decrypt(key, iv, crypted);
console.log("decrypted:", dec);
```