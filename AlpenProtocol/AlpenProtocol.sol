// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./lib/Ownable.sol";
import "./lib/Pausable.sol";
import "./interface/IERC20.sol";
import "./lib/ReentrancyGuard.sol";
import "./lib/SafeERC20.sol";


interface IMintERC20 is IERC20{
    
     function mint(address account,uint256 amount) external  returns(bool);
     
     function burn(address account,uint256 amount) external  returns(bool);
}

interface IDeployer {
    
    function deployer(address o_token) external returns(address i_token,address v_token);
    
}

contract AlpenProtocol is  Ownable,Pausable,ReentrancyGuard {
    
    
    address public g_token;  //for vote
    
    address public y_token; // for investment
    
    address public s_token; //原始参与staking
    

    address public feeReceive;
    
    uint256 public protocolFee;
    
    address public factory;
    
    
    event ChangeStaking(address _o_token);
    
    event Split(address account,uint256 amount);
    
    event Composite(address account,uint256 amount);
    
    constructor(address _deployer,address _s_token,address _feeReceive,uint256 _protocolFee){
        
        (address _y_token,address _g_token)= IDeployer(_deployer).deployer(_s_token);
        
        g_token = _g_token;
        
        y_token = _y_token;
        
        s_token = _s_token;
        
        feeReceive = _feeReceive;
        
        protocolFee = _protocolFee;
        
        factory = msg.sender;
        
    }
    

    function changeStaking(address _s_token)external onlyOwner {
        
        require(_s_token != address(0),"o_token can not be address(0)");
        
        s_token = _s_token;
        
        emit ChangeStaking(s_token);
    }
    
    function changeFee(address _feeReceive,uint256 _protocolFee) public {
        
        require(_msgSender() == factory,"only called by factory");
        
        feeReceive = _feeReceive;
        
        protocolFee = _protocolFee;
    }

    function pause() public  onlyOwner {
           _pause();
    }


    function unpause() public  onlyOwner{
           _unpause();
    }
    
    function split(uint256 amount)external nonReentrant whenNotPaused{
        
        
        require(amount > 0,"split amount can not be zero");
        
        uint256 beforeBalance = IERC20(s_token).balanceOf(address(this));
        
        SafeERC20.safeTransferFrom(IERC20(s_token),_msgSender(),address(this),amount);
        
        uint256 afterBalance = IERC20(s_token).balanceOf(address(this));
        
        uint256 mintAmount = afterBalance - beforeBalance;
        
        
        if(mintAmount > 0) require(IMintERC20(g_token).mint(_msgSender(),mintAmount) && IMintERC20(y_token).mint(_msgSender(),mintAmount)," deposit :: mint fail");
        
        emit Split(_msgSender(),mintAmount);

    }
    
    function composite(uint256 amount)external nonReentrant{
        
        require(amount > 0," withdraw amount can not be zero");
        
        require(IMintERC20(g_token).burn(_msgSender(),amount) && IMintERC20(y_token).burn(_msgSender(),amount),"burn fail");
        
        emit Composite(_msgSender(),amount);
        
        if(feeReceive != address(0) && protocolFee > 0){
            
            uint256 fee = amount * protocolFee / 10000;
            
            SafeERC20.safeTransfer(IERC20(s_token),feeReceive,fee);
            
            amount = amount - fee;
        }
        
        SafeERC20.safeTransfer(IERC20(s_token),_msgSender(),amount);
      
    }
    
}

contract ProtocolFactory is Ownable,ReentrancyGuard {
    
     address public feeReceive;
     
     uint256 public protocolFee;
     
     address public deployer;
     
     event ProtocolCreate(address protocolAddress,address v_token,address i_token);
     
     constructor(address _feeReceive,uint256 _protocolFee,address _deployer){
        
        require(_feeReceive != address(0),"feeReceive can not be zero address");
        
        require(_protocolFee < 10000,"protocolFee must lt 1");
        
        require(_deployer != address(0),"deployer can not be zero address");
        
        feeReceive = _feeReceive;
        
        protocolFee = _protocolFee;
        
        deployer = _deployer;
     }

    function setFee(address _feeReceive,uint256 _protocolFee) public onlyOwner {
        
        require(_feeReceive != address(0),"feeReceive can not be zero address");
        
        require(_protocolFee < 10000,"protocolFee must lt 1");
        
        feeReceive = _feeReceive;
        
        protocolFee = _protocolFee;
        
    }
    
    function changeSpaceFee(address space,address _feeReceive,uint256 _protocolFee)public onlyOwner{
        
        require(_feeReceive != address(0),"feeReceive can not be zero address");
        
        require(_protocolFee < 10000,"protocolFee must lt 1");
        
        AlpenProtocol(space).changeFee(_feeReceive,_protocolFee);
        
    }
    
    function changeDeployer(address _deployer) public onlyOwner {
        
         require(_deployer != address(0),"deployer can not be zero address");
         
         deployer = _deployer;
        
    }
    
    
    function createProtocol(address s_token) public nonReentrant{
        
        AlpenProtocol alpenProtocol = new AlpenProtocol(deployer,s_token,feeReceive,protocolFee);
        
        alpenProtocol.transferOwnership(msg.sender);
        
        emit ProtocolCreate(address(alpenProtocol),alpenProtocol.g_token(),alpenProtocol.y_token());
        
    }
    
    
    
}