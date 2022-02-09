var tls = require('tls');
var fs = require('fs');
var options = {
        host: 'localhost',
        port: 2345,
        //key: fs.readFileSync('client-key.pem'),
        //cert: fs.readFileSync('client-cert.pem'),
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
