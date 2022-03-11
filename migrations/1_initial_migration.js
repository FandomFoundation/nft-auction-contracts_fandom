const TikTokNft = artifacts.require("TikTokNft");
const MintAuction = artifacts.require("MintAuction");

module.exports = async function (deployer, network, accounts) {
  let adminAddress, feeAddress;
  if (network === "rinkeby") {
    adminAddress = accounts[0];
    feeAddress = "0x3ea0C9755aaA79e9C7F9fE31062BDCCbDB20F7A6";
    // 先部署nft合约
    await deployer.deploy(
      TikTokNft,
      "", // base_uri
      "Tiktok-test", // name
      "test", // symbol
      adminAddress // admin地址，先随意给一个，部署好auction合约后，再将auction地址设置为admin
    );
    const TikTokNftInstance = await TikTokNft.deployed();
    // 再部署auction合约
    await deployer.deploy(
      MintAuction,
      feeAddress, //收取费用的地址,
      TikTokNftInstance.address,
      3, // 千分之3,
      50 // 每次增加百分之5
    );
    const AuctionInstance = await MintAuction.deployed();
    // 调用合约的方法
    await TikTokNftInstance.addAdmin(AuctionInstance.address);
  } else if (network === "ropsten") {
    adminAddress = accounts[0];
    feeAddress = "0x3ea0C9755aaA79e9C7F9fE31062BDCCbDB20F7A6";
    // 先部署nft合约
    await deployer.deploy(
      TikTokNft,
      "", // base_uri
      "TiktokTest", // name
      "TiktokToken", // symbol
      adminAddress // admin地址，先随意给一个，部署好auction合约后，再将auction地址设置为admin
    );
    const TikTokNftInstance = await TikTokNft.deployed();
    // 再部署auction合约
    await deployer.deploy(
      MintAuction,
      feeAddress, //收取费用的地址,
      TikTokNftInstance.address,
      3, // 千分之3,
      50 // 每次增加百分之5
    );
    const AuctionInstance = await MintAuction.deployed();
    // 调用合约的方法
    await TikTokNftInstance.addAdmin(AuctionInstance.address);
  }
};
