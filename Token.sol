//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract QRT is ERC20, Ownable {
  uint8 public _tax;
  address public _taxer;
  address public _liquidity;
  address public _ownerAddress;

  constructor(address liquidity, address taxer) ERC20("QRT", "QRT") {
    _taxer = taxer;
    _liquidity = liquidity;
    _ownerAddress = msg.sender;
    _tax = 5;
    _mint(msg.sender, 10000000 * 1 ether); // 10M
  }

  function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
    uint256 taxAmount = 0;
    
    // if sender or receiver is different to owner, liquidity or taxer address, apply tax
    if (sender != _ownerAddress && receiver != _ownerAddress 
        && sender != _liquidity && receiver != _liquidity
        && sender != _taxer && receiver != _taxer) {
      taxAmount = (amount * _tax) / 100;
    }
    
    if (taxAmount > 0){
      super._transfer(sender, _taxer, taxAmount);
    }
    
    super._transfer(sender, receiver, amount - taxAmount);
  }

  function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override {
    require(_to != address(this), string("No transfers to contract allowed."));    
    super._beforeTokenTransfer(_from, _to, _amount);
  }

}