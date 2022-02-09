var tls = require('tls');
var fs = require('fs');
var options = {
        key: fs.readFileSync('server-key.pem'),
        cert: fs.readFileSync('server-cert.pem'),
        //ca: [ fs.readFileSync('server-cert.pem') ],
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
