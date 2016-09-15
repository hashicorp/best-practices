var http = require("http"),
    fs = require("fs"),
    vaultDir = "/application/vault/",
    showVault = process.env.SHOW_VAULT,
    vaultFiles = process.env.VAULT_FILES,
    vaultSecret = process.env.SECRET_KEY,
    files = [],
    port = 8888;

function handleRequest(req, res) {
  res.writeHead(200, {"Content-type":"text/html"});
  res.write("Hello, World! This is Node.js app v99.");

  // Only show Vault files if the SHOW_VAULT KV is set to true in Consul
  if (fs.existsSync(vaultDir) && showVault && (showVault.toUpperCase() === "TRUE" || showVault === "1")) {
    files = fs.readdirSync(vaultDir);

    for (var i = 0; i < files.length; i++) {
      file = files[i];

      // Only show this file if included in the VAULT_FILES KV in Consul
      if (vaultFiles && vaultFiles.indexOf(file) > -1) {
        res.write(fs.readFileSync(vaultDir + file, "binary"));
      }
    }
  }

  res.end();
}

http.createServer(handleRequest).listen(port);

console.log("Static file server running at\n  => http://localhost:" + port);
