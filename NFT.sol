//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract NFT is ERC721URIStorage, ReentrancyGuard, Ownable {
    // counters allow us to keep track of tokenIds
    using Counters for Counters.Counter;
    Counters.Counter public COUNTER;
    string private _baseTokenURI = "https://quoverflow.com/game/token/";

    
    address payable public _liquidity; // address to liquidity
    address payable public _taxer; // address to store commissions

    constructor(address payable liquidityAddress, address payable taxer, IERC20 token) ERC721("Quo", "Quo") {
        _token = token;
        _liquidity = payable(liquidityAddress);
        _taxer = payable(taxer);
    }

    // Events
    event EventTokensClaimed(address user, uint256 amount);
    event EventQuoPurchased(address user);
    event EventQuoUpgraded(address user);
    event EventPassChanged(address user);

    // Token
    uint8 _decimals = 18;
    uint256 _scale = 1 * 10 ** _decimals;
    IERC20 public _token; // _token QRT
    uint256 public _tokenQty = 9000000 * _scale; // initial qty
    uint256 public _halving1 = 4500000 * _scale; // halving 1
    uint256 public _halving2 = 2250000 * _scale; // halving 2
    uint256 public _halving3 = 1125000 * _scale; // halving 3
    uint256 public _halving4 =  562500 * _scale; // halving 4
    uint256 public _halving5 =  281250 * _scale; // halving 5
    uint256 public _halving6 =  140625 * _scale; // halving 6
    uint256 public _halving7 =   70312 * _scale; // halving 7

    // Mappings
    mapping(uint256 => Quo) public _quos; // 
    mapping(address => uint) private _pass; // 

    // Rewards
    uint256 claimQuo = 120 hours; // reward goal 5 days
    
    // Struct
    struct Quo {
        uint256 id;
        uint256 power;
        uint lastClaim;
        uint lvl;
        uint rare;
    }

    function quoOfId(uint256 tokenId) public view returns(Quo memory) { 
        return _quos[tokenId];
    }

    function login(address user, uint password) external onlyOwner view returns (bool) {
        if (_pass[user] == password){
            return true;
        }
        return false;
    }

    function changePass(uint password) external {
        _pass[msg.sender] = password;
        emit EventPassChanged(msg.sender);
    }

    function dailyReward() public nonReentrant{
        uint256 amount = 0;
        
        require(_token.balanceOf(address(this)) > 0, "No reward tokens left");        
        
        Quo[] memory myQuos = getOwnerQuos(msg.sender);

        for (uint i = 0; i < myQuos.length; i++) {
            if (block.timestamp >= _quos[myQuos[i].id].lastClaim + claimQuo) {
                amount += myQuos[i].power;
                _quos[myQuos[i].id].lastClaim = block.timestamp;
            }
        }
        
        require(amount > 0, "not rewards to claim");
        amount = amount * _scale * 5; // 5 days
        amount = halvingAmount(amount);

        _token.transfer(msg.sender, amount);
        
        emit EventTokensClaimed(msg.sender, amount);
    }
    
    function halvingAmount(uint256 amount) private view returns (uint256 newAmount) {
        if (_token.balanceOf(address(this)) > _halving1){
            return amount;
        }else if (_token.balanceOf(address(this)) > _halving2){
            return amount / 2;
        }else if (_token.balanceOf(address(this)) > _halving3){
            return amount / 4;
        }else if (_token.balanceOf(address(this)) > _halving4){
            return amount / 8;
        }else if (_token.balanceOf(address(this)) > _halving5){
            return amount / 16;
        }else if (_token.balanceOf(address(this)) > _halving6){
            return amount / 32;
        }else if (_token.balanceOf(address(this)) > _halving7){
            return amount / 64;
        }
        return amount/128;
    }

    // function to upgrade lvl nft
    function upgradeQuo(uint256 itemID) public payable {
        require(_quos[itemID].id >= 0, "invalid id");
        require(_quos[itemID].lvl < 10, "currently have lvl 10");

        if (_quos[itemID].lvl == 0) {
            require(msg.value >= 0.1 ether, "pay at least 0.1");
        }else if (_quos[itemID].lvl == 1) {
            require(msg.value >= 0.2 ether, "pay at least 0.2");
        }else if (_quos[itemID].lvl == 2) {
            require(msg.value >= 0.3 ether, "pay at least 0.3");
        }else if (_quos[itemID].lvl == 3) {
            require(msg.value >= 0.4 ether, "pay at least 0.4");
        }else if (_quos[itemID].lvl == 4) {
            require(msg.value >= 0.5 ether, "pay at least 0.5");
        }else if (_quos[itemID].lvl == 5) {
            require(msg.value >= 0.6 ether, "pay at least 0.6");
        }else if (_quos[itemID].lvl == 6) {
            require(msg.value >= 0.7 ether, "pay at least 0.7");
        }else if (_quos[itemID].lvl == 7) {
            require(msg.value >= 0.8 ether, "pay at least 0.8");
        }else if (_quos[itemID].lvl == 8) {
            require(msg.value >= 0.9 ether, "pay at least 0.9");
        }else {
            require(msg.value >= 1 ether, "pay at least 1");
        }

        uint v1=msg.value*5;
        uint shareForX=v1/100;
        uint tax=shareForX;

        payable(_taxer).transfer(tax);

        uint p = _quos[itemID].power*10;
        uint percent=p/100;
        
        if (percent < 1) {
            percent = 1;
        }

        _quos[itemID].power += percent;
        _quos[itemID].lvl += 1;

        if (_quos[itemID].power > 300) {
            _quos[itemID].power = 300;
        }

        emit EventQuoUpgraded(msg.sender);
    }

    // Buy Quo
    function purchaseQuo() public payable {
        COUNTER.increment();
        require(msg.value == 0.1 ether, "pay 0.1 ether");

        uint v1=msg.value*5;
        uint shareForX=v1/100;
        uint tax=shareForX;

        payable(_taxer).transfer(tax);

        uint256 newItemId = COUNTER.current();
        _mint(msg.sender, newItemId);

        _setTokenURI(newItemId, _baseTokenURI);
        // give the marketplace the approval to transact between users
        //setApprovalForAll(marketAddress, true);
        
        uint256 randPower = uint8(_createRandomNum(300))+1;
        uint256 randRare = uint8(_createRandomNum(4))+1;

        Quo memory newQuo = Quo(COUNTER.current(), randPower, block.timestamp, 0, randRare);
        _quos[newItemId]=newQuo;

        emit EventQuoPurchased(msg.sender);
    }

    // Getters
    function MyQuos() public view returns(Quo[] memory){
        return getOwnerQuos(msg.sender);
    }
    
    function getOwnerQuos(address owner_) private view returns (Quo[] memory) {
        uint256 totalMyQuos = balanceOf(owner_);
        Quo[] memory myQuos = new Quo[](totalMyQuos);
        uint256 counter = 0;
        for (uint256 i = 0; i < COUNTER.current(); i++) {
          if (ownerOf(i+1) == owner_) {
            myQuos[counter] = _quos[i+1];
            counter++;
          }
        }
        return myQuos;
    }

    // Helpers
    function _createRandomNum(uint256 _mod) internal view returns (uint256) {
        uint256 randomNum = uint256(
        keccak256(abi.encodePacked(block.timestamp, msg.sender))
        );
        return randomNum % _mod;
    }

    function BnbToLiqAdd() external {
        _liquidity.transfer(address(this).balance);
    }
}