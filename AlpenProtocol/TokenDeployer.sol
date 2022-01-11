// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./lib/Ownable.sol";
import "./InvestmentERC20.sol";
import "./VoteToken.sol";



contract TokenDeployer {
    
     
    function deployer(address o_token) public returns(address i_token,address v_token){
        
        string memory name = IERC20Metadata(o_token).name();
        
        string memory symbol = IERC20Metadata(o_token).symbol();

        uint8 decimals = IERC20Metadata(o_token).decimals();
        
        VoteToken v_ = new VoteToken(string(abi.encodePacked("G",name)),string(abi.encodePacked("G",symbol)),decimals);
        
        v_.transferOwnership(msg.sender);
        
        v_token = address(v_);
        
        InvestmentERC20 i_ = new InvestmentERC20(string(abi.encodePacked("Y",name)),string(abi.encodePacked("Y",symbol)),decimals);
        
        i_.transferOwnership(msg.sender);
        
        i_token = address(i_);
        
    }
}



