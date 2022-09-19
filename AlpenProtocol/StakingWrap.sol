// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./lib/Ownable.sol";
import "./lib/ReentrancyGuard.sol";
import "./lib/SafeERC20.sol";
import "./lib/Pausable.sol";


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

interface IStaking {

        function pause() external;

        function unpause() external;

        function updateMinDeposit(uint256 _minPerDeposit) external;

        function updateStartAndEnd(uint256 satrt,uint256 end)external;

        function updateReward(uint256 _rewardPerBlock) external;

        function deposit(uint256 amount) external;

        function withdraw(uint256 voucherAmount) external;

        function getTotalStaking()external  view returns(uint256 _totalstaking);

        function totalDepositUser()external  view returns(uint256 );

        function recoverERC20(address tokenAddress, uint256 tokenAmount) external;

       
}

contract StakingWrap is Ownable,ReentrancyGuard,Pausable{

    IStaking public staking;

    address public voucher;
    
    address public stakingToken;
    
    uint256 public startTime;
    
    uint256 public endTime;
                                 
    uint256 public rewardPerSecond = 540000000000000000;
    
    uint256 public lastRewardTime;
    
    uint256 private totalStaking;
    
    uint256 public minPerDeposit;

    uint256 public totalDepositUser;

    uint256 public stakingPoolTotal;

    event Deposit(address account,uint256 amount,uint256 v_amount);
    
    event Withdraw(address account,uint256 amount,uint256 v_amount);


    modifier collectReward(){
        
        uint256 satrt = Math.max(startTime,lastRewardTime);
        uint256 end = Math.min(endTime,block.timestamp);
        if(totalStaking > 0 && end > satrt ){
            totalStaking = totalStaking + (end - satrt) * rewardPerSecond;
            lastRewardTime = end;
        }
        _;
    }


     constructor(address _staking,address _stakingToken,address _voucher,uint256 _endTime) {

         staking = IStaking(_staking);

         stakingToken = _stakingToken;

         voucher = _voucher;

         totalStaking = staking.getTotalStaking();

         totalDepositUser = staking.totalDepositUser();

         stakingPoolTotal = totalStaking;

         startTime = block.timestamp;

         endTime = _endTime;

         SafeERC20.safeApprove(IERC20(stakingToken),address(staking),type(uint256).max);

     }

    function pause() public  onlyOwner {
           _pause();
    }


    function unpause() public  onlyOwner{
           _unpause();
    }


    function updateEnd(uint256 end)public onlyOwner {
        
        require(end > block.timestamp,"end must bt now");

        if(endTime > block.timestamp){
            
            endTime = end;

        } else {

            startTime = block.timestamp;

            endTime = end;
        }
    
    }


   function updateReward(uint256 _rewardPerSecond) public onlyOwner collectReward{
        
        rewardPerSecond = _rewardPerSecond;
    }

    function deposit(uint256 amount) public nonReentrant whenNotPaused  {
          
          uint256 _totalstaking = totalStaking;

          _totalstaking = reCulTotalStaking(_totalstaking);

          totalStaking = _totalstaking;

          _deposit(amount);

          stakingPoolTotal = staking.getTotalStaking();
    }



   function _deposit(uint256 amount) internal collectReward {
        
        require(block.timestamp <= endTime,"deposit :: close" );
        
        require(amount >= minPerDeposit,"deposit :: amount must bt zero");
        
        SafeERC20.safeTransferFrom(IERC20(stakingToken),_msgSender(),address(this),amount);

        uint256  odlTotalStaking = staking.getTotalStaking();
        
        uint256 depositAmount;
        
        if(totalStaking == 0){
            
             depositAmount = amount;
             
        }else{
            
            depositAmount = odlTotalStaking * amount / totalStaking;
            
        }

        staking.unpause();

        uint256 balanceBefore = IERC20(voucher).balanceOf(address(this));

        staking.deposit(depositAmount);

        uint256 balanceAfter = IERC20(voucher).balanceOf(address(this));

        require(balanceAfter > balanceBefore,"deposit:: fail");

        SafeERC20.safeTransfer(IERC20(voucher),_msgSender(),balanceAfter - balanceBefore);
        
        totalStaking += amount;
        
        totalDepositUser ++;

        staking.pause();

        emit Deposit(_msgSender(),amount,balanceAfter - balanceBefore);
    }

     function withdraw(uint256 voucherAmount) public nonReentrant {

          uint256 _totalstaking = totalStaking;

          _totalstaking = reCulTotalStaking(_totalstaking);

          totalStaking = _totalstaking;

          _withdraw(voucherAmount);

          stakingPoolTotal = staking.getTotalStaking();

     }
    
    
    function _withdraw(uint256 voucherAmount) internal collectReward {
        
        
        require(voucherAmount > 0,"withdraw :: amount must bt zero");

        SafeERC20.safeTransferFrom(IERC20(voucher),_msgSender(),address(this),voucherAmount);

        uint256 w = voucherAmount * totalStaking / IERC20(voucher).totalSupply();

        staking.withdraw(voucherAmount);
        
        SafeERC20.safeTransfer(IERC20(stakingToken),_msgSender(),w);
        
        totalStaking -= w;
        
        emit Withdraw(_msgSender(),w,voucherAmount);
    }


  function query(uint256 voucherAmount) public view returns(uint256){

        uint256 temp = totalStaking;

        temp = reCulTotalStaking(temp);
        
        uint256 satrt = Math.max(startTime,lastRewardTime);
        
        uint256 end = Math.min(endTime,block.timestamp);
        
        if(temp >0 && end > satrt ){
            
            temp = temp + (end - satrt) * rewardPerSecond;
            
        }
        
        return voucherAmount * temp / IERC20(voucher).totalSupply();
    }

    function getTotalStaking()public view returns(uint256 _totalstaking){

        _totalstaking = totalStaking;

        _totalstaking = reCulTotalStaking(_totalstaking);

        uint256 satrt = Math.max(startTime,lastRewardTime);

        uint256 end = Math.min(endTime,block.timestamp);

        if(_totalstaking > 0 && end > satrt ){

            _totalstaking = _totalstaking + (end - satrt) * rewardPerSecond;

        } 
    }


    function reCulTotalStaking(uint256 _totalstaking) private view returns(uint256) {

        uint256 currentStakingPoolTotal = staking.getTotalStaking();

        if(currentStakingPoolTotal != stakingPoolTotal) {

              _totalstaking = _totalstaking + currentStakingPoolTotal - stakingPoolTotal;
        }

        return _totalstaking;

    }

  function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        //require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        SafeERC20.safeTransfer(IERC20(tokenAddress),owner(), tokenAmount);
    
    }

    function changeStakingOwner(address _newOwner)  external onlyOwner {

         Ownable(address(staking)).transferOwnership(_newOwner);
    }

}