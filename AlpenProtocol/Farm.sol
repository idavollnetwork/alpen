// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface AlpenToken{
     /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
     
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    
    
    function mint(address account, uint256 amount) external ;

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.

    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; 
        uint256 allocPoint;
        uint256 lastRewardBlock; 
        uint256 accPerShare; 
        uint256 startBlock;
        uint256 endBlock;
    }
    // The SUSHI TOKEN!
    AlpenToken public alpen;



    // Info of each pool. 
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens. 
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    
    event AddPool(uint256 allocPoint,address lpToken,uint256 startBlock,uint256 endBlock,uint256 pid); 

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    
    event EmergencyWithdraw(address indexed user,uint256 indexed pid,uint256 amount);


    constructor( AlpenToken _alpen) {

        alpen = _alpen;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint256 _startBlock,
        uint256 _endBlock
    ) public onlyOwner {
        require(_startBlock < _endBlock,"Bonus block error");

        uint256 lastRewardBlock = block.number > _startBlock ? block.number : _startBlock;
        
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPerShare: 0,
                startBlock:_startBlock,
                endBlock:_endBlock
            })
        );
        
        emit AddPool(_allocPoint,address(_lpToken),_startBlock,_endBlock,poolInfo.length -1);
    }

    // Update the given pool's SUSHI allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
           updatePool(_pid);
        }

        poolInfo[_pid].allocPoint = _allocPoint;
    }



    // Return reward multiplier over the given _from to _to block. 
    function getMultiplier(uint256 _pid,uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        require(_to >= _from,"Block discord rule");
        
        PoolInfo storage pool = poolInfo[_pid];
        
        if (_from > pool.endBlock) {
            return 0;
        } else if (_to >= pool.endBlock) {
            return pool.endBlock - _from;
        } else {
            return  _to - _from;
               
        }
    }

    // View function to see pending SUSHIs on frontend. 
    function pendingToken(uint256 _pid, address _user) external view returns (uint256){
        PoolInfo storage pool = poolInfo[_pid];
        
        UserInfo storage user = userInfo[_pid][_user];
        
        uint256 accPerShare = pool.accPerShare;
        
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(_pid,pool.lastRewardBlock, block.number);
            
            uint256 alpenReward = multiplier * pool.allocPoint * 1e6;
            
            accPerShare = accPerShare + alpenReward / lpSupply;
        }
        
        return user.amount * accPerShare / 1e6 - user.rewardDebt;
    }

    // Update reward variables of the given pool to be up-to-date. 
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(_pid,pool.lastRewardBlock, block.number);
        
        uint256 alpenReward = multiplier * pool.allocPoint * 1e6;

        pool.accPerShare = pool.accPerShare + alpenReward / lpSupply;
        
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for SUSHI allocation. 
    function deposit(uint256 _pid, uint256 _amount) public {
 
        PoolInfo storage pool = poolInfo[_pid];
        
        require(block.number <= pool.endBlock,"The award has ended");
        
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        updatePool(_pid);
        
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accPerShare / 1e6 - (user.rewardDebt);
            
            alpen.mint(msg.sender, pending);
        }
        
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        
        user.amount = user.amount + _amount;
        
        user.rewardDebt = user.amount * pool.accPerShare / 1e6;
        
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef. 
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        require(user.amount >= _amount, "withdraw: not good");
        
        updatePool(_pid);
        
        uint256 pending = user.amount * pool.accPerShare / 1e6 - user.rewardDebt;
        
        alpen.mint(msg.sender, pending);
        
        user.amount = user.amount - _amount;
        
        user.rewardDebt = user.amount * pool.accPerShare / 1e6;
        
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        
        UserInfo storage user = userInfo[_pid][msg.sender];
        
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        
        user.amount = 0;
        
        user.rewardDebt = 0;
    }

    
    function getPoolInfo(uint256 _pid) external view returns(uint256 _poolTotal,uint256 _startBlock,uint256 _endBlock,uint256 _rewardNum,address _lpToken){
        PoolInfo storage pool = poolInfo[_pid];
        
        uint256 poolTotal =  pool.lpToken.balanceOf(address(this));
        
        
        return(poolTotal,pool.startBlock,pool.endBlock,pool.allocPoint,address(pool.lpToken));
        
    }

        // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        //require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    
    }
}
