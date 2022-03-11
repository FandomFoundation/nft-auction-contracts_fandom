// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


interface TikTokERC721 {
    function balanceOf(address _owner) external view returns (uint256);
    function ownerOf(uint256 _tokenId) external view returns (address);
    
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) external payable;
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    
    function approve(address _approved, uint256 _tokenId) external payable;
    function setApprovalForAll(address _operator, bool _approved) external;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

    function adminMint(address _to, string memory _tokenUri) external returns(uint256);
}


contract MintAuction is Ownable {

    using Strings for uint256;
    using SafeMath for uint256; 

    address public nftAddress; //Address of NFT contract
    address public feeAddress; //Collection address of handling charges 
    uint256 public feeRate; //Transaction handling rate
    uint256 public increaseLimit; //Lowest bid proportion

    bool private lock;

    struct AuctionItem {
        uint256 auctionId;
        uint256 tokenId; // NFT token-id generated after receive
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        address author;
        address bidder;
        bool state;
    }

    mapping(uint256 => AuctionItem) auctions; //Collection of auctions
    mapping(address => mapping(uint256 => uint256)) public refund;

    // *******************
    // EVENTS
    // *******************
    event AuctionRelease(address indexed author, uint256 indexed auctionId, uint256 price);
    event Bid(address indexed bidder, uint256 indexed auctionId, uint256 price, uint256 time);
    event AuctionReceive(address indexed bidder, uint256 indexed auctionId, uint256 tokenId, uint256 price, uint256 fee);
    event Refund(address indexed bidder, uint256 indexed auctionId, uint256 price);
    event RefundTransfer(address indexed bidder, uint256 indexed auctionId, uint256 price);

    modifier getLock() {
        require(lock, "non reentrant");

        lock = false;

        _;

        lock = true;
    }

    constructor (
        address _operator,
        address _nft,
        uint256 _rate,
        uint256 _limit
    ) {
        require(_operator != address(0), "address can not be 0");
        require(_nft != address(0), "address can not be 0");
        require(_rate < 1000, "_rate must be less than 1000");
        require(_limit < 1000, "_limit must be less than 1000");
        feeAddress = _operator;
        nftAddress = _nft;
        feeRate = _rate;
        increaseLimit = _limit;
        lock = true; 
    }


    /**
     * @dev Set the address to charge the handling fee.
     * @param _operator address
     */
    function setFeeAddress(address _operator) public onlyOwner {
        require(_operator != address(0), "address can not be 0");
        feeAddress = _operator;
    }

    /**
     * @dev Set the address of NFT contract.
     * @param _nft contract address
     */
    function setNftAddress(address _nft) public onlyOwner {
        require(_nft != address(0), "address can not be 0");
        nftAddress = _nft;
    }

    /**
     * @dev Set transaction fee proportion.
     * @param  _rate / 1000
     */
    function setFeeRate(uint256 _rate) public onlyOwner {
        require(_rate < 1000, "_rate must be less than 1000");
        feeRate = _rate;
    }

    /**
     * @dev Set minimum price increase.
     * @param _limit / 1000
     */
    function setIncreaseLimit(uint256 _limit) public onlyOwner {
        require(_limit < 1000, "_limit must be less than 1000");
        increaseLimit = _limit;
    }


    /**
     * @dev Release an auction item.
     */
    function auctionRelease (uint256 _auctionId, address _author, uint256 _price, uint256 _startTime, uint256 _endTime) public onlyOwner {    
        require(_auctionId > 0, "params error: auctionId must be greater than 0 ");
        require(_price >= 1000,"params error: price must be greater than 1000");
        require(_startTime < _endTime, "params error: time");
        require(_author != address(0),"params error: author can not be 0");
        require(! isContract(_author),"params error: Author must be an external account");

        AuctionItem storage auction = auctions[_auctionId];
        
        if(auction.auctionId > 0){
            require(auction.state == false, "Auction completed");
            require(auction.bidder == address(0), "Waiting for collection");
            require(block.timestamp > auction.endTime,"It's not over yet");
        }
        

        auction.auctionId = _auctionId;
        auction.price = _price;
        auction.author = _author;
        auction.startTime = _startTime;
        auction.endTime = _endTime;
        
        emit AuctionRelease(_author, _auctionId, _price);
    }
    

    function getAuction(uint256 _auctionId) public view returns(AuctionItem memory) {
        return auctions[_auctionId];
    }


    /**
     * @dev Bid on the auction items and return the assets of the last bidder.
     */
    function bid(uint256 _auctionId) external payable getLock {
        
        AuctionItem storage auction = auctions[_auctionId];
        require(tx.origin == msg.sender,"Available only for external accounts");
        require(auction.auctionId > 0,"the auction not exists");
        require(block.timestamp > auction.startTime,"auction has not started");
        require(block.timestamp < auction.endTime,"auction is over");
        require(_minPrice(auction.price) <= msg.value,"not lower than the minimum price");

        //Pay last payer
        if(auction.bidder != address(0) && auction.price > 0){
            if(! payable(auction.bidder).send(auction.price)){
                refund[auction.bidder][auction.auctionId] = refund[auction.bidder][auction.auctionId].add(auction.price);
                emit Refund(auction.bidder,auction.auctionId, auction.price);
            }
        }

        auction.bidder = msg.sender;
        auction.price = msg.value;

        emit Bid(msg.sender, _auctionId, msg.value, block.timestamp);
    }


    /**
     * @dev Receive auctions and pay to authors and platforms.
     */
    function auctionReceive(uint256 _auctionId) public getLock returns(uint256) {
        AuctionItem storage auction = auctions[_auctionId];
        require(auction.auctionId > 0,"the auction not exists");
        require(auction.state == false, "auction completed");
        require(block.timestamp > auction.endTime, "not finished");

        auction.state = true;

        uint256 fee = auction.price.div(1000).mul(feeRate);
        uint256 amount = auction.price.sub(fee);
        require(amount > 0, "commission calculation error");
        require(amount <= auction.price, "commission calculation error 2");

        if(! payable(auction.author).send(amount)){
            refund[auction.author][auction.auctionId] = refund[auction.author][auction.auctionId].add(amount);
            emit Refund(auction.author,auction.auctionId, amount);
        }
        
        if(fee > 0){
            payable(feeAddress).transfer(fee);
        }

        uint256 tokenId = TikTokERC721(nftAddress).adminMint(auction.bidder, auction.auctionId.toString());

        auction.tokenId = tokenId;

        emit AuctionReceive(auction.bidder, _auctionId, tokenId, auction.price, fee);

        return tokenId;
    }

    /**
     * @dev Get a refund
     */
    function refundTransfer(uint256 _auctionId) external getLock(){
        uint256 amount = refund[msg.sender][_auctionId];
        require(amount > 0,"Insufficient funds");
        refund[msg.sender][_auctionId] = 0;
    
        payable(msg.sender).transfer(amount);
        
        emit RefundTransfer(msg.sender, _auctionId, amount);
    }


    function _minPrice(uint256 _price) private view returns(uint256) {
        if(increaseLimit  > 0 && _price > 0){
            return _price.add(_price.div(1000).mul(increaseLimit));
        }
        return _price;
    }

    function isContract(address _addr) internal view returns (bool) {
        uint size;
        assembly { 
            size := extcodesize(_addr)
        }
        return size > 0;
    }

}

