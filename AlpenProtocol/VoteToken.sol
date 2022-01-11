// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20Votes.sol";
import "./lib/Ownable.sol";

contract VoteToken is ERC20Votes,Ownable {
    
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