//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// security against transactions for multiple requests
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./NFT.sol";
//import "hardhat/console.sol";

contract IQuoFactory{
    struct Quo {
        uint256 id;
        uint256 power;
        uint lastClaim;
        uint lvl;
        uint rare;
    }
    function quoOfId(uint256 tokenId) public view returns(Quo memory) { }
}

contract QuoMarket is ReentrancyGuard {
    using Counters for Counters.Counter;

    /* number of items minting, number of transactions, tokens that have not been sold
     keep track of tokens total number - tokenId
     arrays need to know the length - help to keep track for arrays */
     Counters.Counter public _tokenIds;
     Counters.Counter public _tokensSold;
     
     IQuoFactory _erc721factory;

     address payable public _taxer; // is the taxer with 5% commission

     constructor(address taxer, address nft) {
         _taxer = payable(taxer);
         _erc721factory = IQuoFactory(nft);
     }

     // structs can act like objects
     struct MarketToken {
         uint itemId;
         address nftContract;
         uint256 tokenId;
         address payable seller;
         address payable owner;
         uint256 price;
         bool sold;
         uint256 power;
         uint lvl;
         uint lastClaim;
     }

    // maps
    mapping(uint256 => MarketToken) public idToMarketToken;

    function sellNft(address nftContract, uint256 tokenId, uint256 price) public payable nonReentrant{
        // nonReentrant is a modifier to prevent reentry attack
        // verify that msg.sender is the owner of tokenId
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "You are not the owner");

        require(price > 10, "Price must be greater than 10");

        uint256 power = _erc721factory.quoOfId(tokenId).power;
        uint256 level = _erc721factory.quoOfId(tokenId).lvl;
        uint lastClaim = _erc721factory.quoOfId(tokenId).lastClaim;

        _tokenIds.increment();
        uint256 itemId = _tokenIds.current();

        //putting it up for sale - bool - no owner
        idToMarketToken[itemId] = MarketToken(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false,
            power,
            level,
            lastClaim
        );

        // NFT transaction 
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
    }

    function buyNFT(address nftContract, uint256 itemId) public payable nonReentrant{
        uint price = idToMarketToken[itemId].price;
        uint tokenId = idToMarketToken[itemId].tokenId;
        require(msg.value == price, "Please submit the asking price in order to continue");

        // transfer the token from contract address to the buyer
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketToken[itemId].owner = payable(msg.sender);
        idToMarketToken[itemId].seller = payable(msg.sender);
        idToMarketToken[itemId].sold = true;
        _tokensSold.increment();

        uint v1=msg.value*5;
        uint shareForX=v1/100;
        uint amount=msg.value-shareForX;

        // transfer the amount to the seller
        idToMarketToken[itemId].seller.transfer(amount);
    }

    // removes NFT from selling
    function cancelSellNFT(address nftContract, uint256 itemId) public payable nonReentrant{
        require(false == idToMarketToken[itemId].sold, "This item is not in sale");
        require(msg.sender == idToMarketToken[itemId].seller, "You are not the owner");
            
        idToMarketToken[itemId].owner = payable(msg.sender);
        idToMarketToken[itemId].sold = true;

        // transfer the token from contract to owner
        IERC721(nftContract).transferFrom(address(this), msg.sender, idToMarketToken[itemId].tokenId);
        _tokensSold.increment();
    }

    function getNFTs() public view returns(MarketToken[] memory) {
        uint itemCount = _tokenIds.current();
        uint unsoldItemCount = _tokenIds.current() - _tokensSold.current();
        uint currentIndex = 0;

        // looping over the number of items created (if number has not been sold populate the array)
        MarketToken[] memory items = new MarketToken[](unsoldItemCount);
        for(uint i = 0; i < itemCount; i++) {
            if(idToMarketToken[i + 1].owner == address(this)) {
                MarketToken storage currentItem = idToMarketToken[i + 1];
                items[currentIndex] = currentItem; 
                currentIndex += 1;
            }
        } 
        return items; 
    }

    // function for returning an array of nfts in sale
    function mySellingNFTs() public view returns(MarketToken[] memory) {
        // instead of .owner it will be the .seller
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for(uint i = 0; i < totalItemCount; i++) {
            if(idToMarketToken[i + 1].seller == msg.sender && idToMarketToken[i + 1].sold == false) {
                itemCount += 1;
            }
        }

        // second loop to loop through the amount you have purchased with itemcount
        // check to see if the owner address is equal to msg.sender
        MarketToken[] memory items = new MarketToken[](itemCount);
        for(uint i = 0; i < totalItemCount; i++) {
            if(idToMarketToken[i +1].seller == msg.sender && idToMarketToken[i + 1].sold == false) {
                uint currentId = idToMarketToken[i + 1].itemId;
                MarketToken storage currentItem = idToMarketToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // transfer commissions to owner
    function ToTaxer() external payable {
        _taxer.transfer(address(this).balance);
    }
}
