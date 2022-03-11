var fs = require("fs");

fs.copyFile(
  "build/contracts/TikTokNft.json",
  "dest/contracts/TikTokNft.json",
  (err) => {
    if (err) throw err;
    console.log("✅ TikTokNft contract's ABI was copied to the frontend");
  }
);

fs.copyFile(
  "build/contracts/MintAuction.json",
  "dest/contracts/MintAuction.json",
  (err) => {
    if (err) throw err;
    console.log("✅ MintAuction contract's ABI was copied to the frontend");
  }
);
