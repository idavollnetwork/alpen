// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./lib/Ownable.sol";
import "./lib/ReentrancyGuard.sol";
import "./lib/SafeERC20.sol";
import "./lib/Pausable.sol";

contract PToken is ERC20,Ownable{
    
    
    constructor(string memory name,string memory symbol,uint8 decimals)ERC20(name,symbol,decimals){ }
    
    
    function mint(address account,uint256 amount) external onlyOwner returns(bool){
        
        _mint(account,amount);
        
        return true;
    }
    
    function burn(address account,uint256 amount) external onlyOwner returns(bool){
        
        _burn(account,amount);
        
        return true;
    }
}

interface IMintERC20 is IERC20{
    
     function mint(address account,uint256 amount) external  returns(bool);
     
     function burn(address account,uint256 amount) external  returns(bool);
}

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute.
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// /**
//  * @dev Provides a function to batch together multiple calls in a single external call.
//  *
//  * _Available since v4.1._
//  */
// abstract contract Multicall {
//     /**
//     * @dev Receives and executes a batch of function calls on this contract.
//     */
//     function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
//         results = new bytes[](data.length);
//         for (uint i = 0; i < data.length; i++) {
//             results[i] = Address.functionDelegateCall(address(this), data[i]);
//         }
//         return results;
//     }
// }

contract Staking is ReentrancyGuard,Ownable,Pausable{
    
    address public voucher;
    
    address public stakingToken;
    
    uint256 public startBlock;
    
    uint256 public endBlock;
                                    
    uint256 public rewardPerBlock = 4500000000000000000;
    
    uint256 public lastRewardBlock;
    
    uint256 private totalStaking;
    
    uint256 public minPerDeposit;

    uint256 public totalDepositUser;
    
    event Deposit(address account,uint256 amount,uint256 v_amount);
    
    event Withdraw(address account,uint256 amount,uint256 v_amount);
    
    
    
    constructor(address _stakingToken,uint256 _startBlock,uint256 _endBlock,uint256 _minPerDeposit){
        
        require(_stakingToken != address(0),"StakingToken can not be address(0)");
        require(_startBlock >= block.number && _endBlock > _startBlock,"startBlock must lt endBlock");
        startBlock = _startBlock;
        endBlock = _endBlock;
        string memory name = IERC20Metadata(_stakingToken).name();
        string memory symbol = IERC20Metadata(_stakingToken).symbol();
        uint8  decimals_ = IERC20Metadata(_stakingToken).decimals();
        PToken p_ = new PToken(string(abi.encodePacked("X",name)),string(abi.encodePacked("X",symbol)),decimals_);
        voucher = address(p_);
        stakingToken = _stakingToken;
        minPerDeposit = _minPerDeposit;
    }
    
    modifier collectReward(){
        
        uint256 satrt = Math.max(startBlock,lastRewardBlock);
        uint256 end = Math.min(endBlock,block.number);
        if(totalStaking > 0 && end > satrt ){
            totalStaking = totalStaking + (end - satrt) * rewardPerBlock;
            lastRewardBlock = end;
        }
        _;
    }
    
    function pause() public  onlyOwner {
           _pause();
    }


    function unpause() public  onlyOwner{
           _unpause();
    }
    
    function updateMinDeposit(uint256 _minPerDeposit) public onlyOwner {
        
        minPerDeposit = _minPerDeposit;
        
    }
    
    function updateStartAndEnd(uint256 satrt,uint256 end)public onlyOwner {
        
        if(lastRewardBlock == 0 && satrt > block.number){
            
            startBlock = satrt;
        }
        
        if(endBlock > block.number && end > block.number){
            
            endBlock = end;
        }
        
        
    }
    
    function updateReward(uint256 _rewardPerBlock) public onlyOwner collectReward{
        
        rewardPerBlock = _rewardPerBlock;
    }
    
    function deposit(uint256 amount) public nonReentrant whenNotPaused collectReward {
        
        require(block.number <= endBlock,"deposit :: close" );
        
        require(amount >= minPerDeposit,"deposit :: amount must bt zero");
        
        SafeERC20.safeTransferFrom(IERC20(stakingToken),_msgSender(),address(this),amount);
        
        uint256 mintAmount;
        
        if(totalStaking == 0){
            
             mintAmount = amount;
             
        }else{
            
            mintAmount = IERC20(voucher).totalSupply() * amount / totalStaking;
            
        }
        
        require(IMintERC20(voucher).mint(_msgSender(),mintAmount),"Deposit :: mint voucher fail");
        
        totalStaking += amount;
        
        totalDepositUser ++;
        emit Deposit(_msgSender(),amount,mintAmount);
    }
    
    
    function withdraw(uint256 voucherAmount) public nonReentrant collectReward {
        
        
        require(voucherAmount > 0,"withdraw :: amount must bt zero");
        
        uint256 w = voucherAmount * totalStaking / IERC20(voucher).totalSupply();
        
        require(IMintERC20(voucher).burn(_msgSender(),voucherAmount),"withdraw :: burn voucher fail");
        
        SafeERC20.safeTransfer(IERC20(stakingToken),_msgSender(),w);
        
        totalStaking -= w;
        
        emit Withdraw(_msgSender(),w,voucherAmount);
    }
    
    function query(uint256 voucherAmount) public view returns(uint256){
        
        uint256 satrt = Math.max(startBlock,lastRewardBlock);
        
        uint256 end = Math.min(endBlock,block.number);
        
        uint256 temp = totalStaking;
        
        if(end > satrt ){
            
            temp = totalStaking + (end - satrt) * rewardPerBlock;
            
        }
        
        return voucherAmount * temp / IERC20(voucher).totalSupply();
    }

    function getTotalStaking()public view returns(uint256 _totalstaking){
        uint256 satrt = Math.max(startBlock,lastRewardBlock);
        uint256 end = Math.min(endBlock,block.number);
        _totalstaking = totalStaking;
        if(_totalstaking > 0 && end > satrt ){
            _totalstaking = _totalstaking + (end - satrt) * rewardPerBlock;
        } 
    }

            // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        //require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        SafeERC20.safeTransfer(IERC20(tokenAddress),owner(), tokenAmount);
    
    }
    
}