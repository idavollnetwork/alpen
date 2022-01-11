pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";

library SafeMath {

    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
        return c;
    }

    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }

    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
        return c;
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the `nonReentrant` modifier
 * available, which can be aplied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}
    
contract Vault is ReentrancyGuard,ERC721Holder {
    using SafeMath for uint256;
    struct AssetInfo {
        bool isErc20;
        uint256 pos;
        uint256[] tokenIDs;
        mapping(uint256 => bool) idsExsit;
    }
    /* ========== STATE VARIABLES ========== */
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
 
 
    mapping(address => AssetInfo) assetExsit;
    address[] public assets;
    

    address public owner;
    address public daoOwner;
    address public voteToken;

    /* ========== EVENTS ========== */
    event Withdrawn(address indexed token,address user, uint256 amount0,uint256 amount1);
    event Deposit(address indexed token,address user, uint256 amount);
    /* ========== CONSTRUCTOR ========== */
    modifier onlyDao() {
        require(msg.sender == daoOwner, "Caller is not DAO contract");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    constructor(address dao,address _voteToken) {
        owner = msg.sender;
        daoOwner = dao;
        voteToken = _voteToken;
    }
    function voteTotal() public view returns (uint256) {
        return IERC20(voteToken).totalSupply();
    }
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Vault: TRANSFER_FAILED');
    }
    
    function isVoultAsset(address token) public view returns (bool exsit,bool erc20) {
        AssetInfo storage info = assetExsit[token];
        if (info.pos == 0) {
            exsit = false;
            erc20 = false;
        } else {
            exsit = true;
            erc20 = info.isErc20;
        }
    }
    
    function _register(address token,bool iserc20,uint256 tokenid) internal {
        if (assetExsit[token].pos == 0) {
            assets.push(token);
            AssetInfo storage info = assetExsit[token];
            info.pos = assets.length+1;
            info.isErc20 = iserc20;
            info.idsExsit[tokenid] = true;
            info.tokenIDs.push(tokenid);
        } else {
            AssetInfo storage info = assetExsit[token];
            if (!info.idsExsit[tokenid]) {
                info.idsExsit[tokenid] = true;
                info.tokenIDs.push(tokenid);
            }
        }
    }
    function deposit(address token,uint256 amount) external {
        IERC20(token).transferFrom(msg.sender,address(this),amount);
        _register(token,true,0);
        emit Deposit(token,msg.sender,amount);
    }
    function depositNFT(address nftToken,uint256 tokenId) external {
        IERC721(nftToken).safeTransferFrom(msg.sender,address(this),tokenId);
        _register(nftToken,false,tokenId);
        emit Deposit(nftToken,msg.sender,tokenId);
    }
    function withdraw(address to, uint256 amount) internal onlyOwner {
        uint256 total = voteTotal();
        require(total >= amount && to != address(0), "Cannot withdraw 0");
        for (uint256 i; i < assets.length; i++) {
            if (assetExsit[assets[i]].isErc20) {
                uint256 _totalSupply = total;
                uint256 balance0 = IERC20(assets[i]).balanceOf(address(this));
                uint256 amount0 = amount.mul(balance0) / _totalSupply ; 
                _safeTransfer(assets[i], to, amount0);
            }
        }
    }
    
    function opTransfer(address token, address to, uint256 amount) external onlyDao {
        // only dao op by proposal
        IERC20(token).transfer(to,amount);
    }
    function opTransferNFT(address token, address to, uint256 tokenid) external onlyDao {
        // only dao op by proposal
        (bool exsit,bool erc20) = isVoultAsset(token);
        require(exsit && !erc20,"opTransferNFT error");
        IERC721(token).transferFrom(address(this),to,tokenid);
    }
    // **** Emergency functions ****
    function execute(address _target, bytes memory _data)
        public
        onlyOwner
        payable
        returns (bytes memory response)
    {
        require(_target != address(0), "!target");

        // call contract in current context
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _target,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            response := mload(0x40)
            mstore(
                0x40,
                add(response, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    revert(add(response, 0x20), size)
                }
        }
    }
    
    function exit() external {
    }

}