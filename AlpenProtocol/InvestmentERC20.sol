// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./lib/Ownable.sol";
import "./draft-ERC20Permit.sol";


contract InvestmentERC20 is ERC20Permit,Ownable{
    
    
    constructor(string memory name,string memory symbol,uint8 decimals)ERC20(name,symbol,decimals)ERC20Permit(name){ }
    
    
    function mint(address account,uint256 amount) external onlyOwner returns(bool){
        
        _mint(account,amount);
        
        return true;
    }
    
    function burn(address account,uint256 amount) external onlyOwner returns(bool){
        
        _burn(account,amount);
        
        return true;
    }
}