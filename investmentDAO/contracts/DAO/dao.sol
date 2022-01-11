pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../vault/vault.sol";


contract base_coin is ERC20{
    
    struct VoteInfo {
        mapping(address => uint256) voteinfos;
        uint256 all;
        bool isused;
        uint256 begin;
        uint256 end;
    }
    
    mapping(uint256 => VoteInfo) private _votes;
    uint256[] private _totalIds;
    address _rootAccount;
    
    constructor(string memory name_, string memory symbol_,uint256 amount) ERC20(name_,symbol_) {
        _rootAccount = _msgSender();
        mint(_msgSender(),amount);
    }
    
    modifier onlyRoot() {
        require(_msgSender() == _rootAccount, "base_coin: onlyRoot");
        _;
    }
    event ChangeRoot(address indexed from, address indexed to);
    event CreateProposal(uint256 indexed pid, address indexed owner,uint256 begin,uint256 end);
    event VoteEvent(uint256 indexed pid, address indexed who,uint256 indexed amount);
    event CancelVote(uint256 indexed pid, address indexed who,uint256 indexed amount);
    event FinishProposal(uint256 indexed pid, address indexed who,address[] accounts);
    
    function changeRoot(address root) public onlyRoot {
        require(root == address(0), "change_root,invalid root address!");
        address from = _rootAccount;
        _rootAccount = root;
        emit ChangeRoot(from, _rootAccount);
    }
    
    function maxLockedBalanceOf(address account) public view returns (uint256) {
        uint256 amount = 0;
        for (uint256 i = 0; i < _totalIds.length; ++i) {
            if (amount == 0) {
                amount = _votes[_totalIds[i]].voteinfos[account];
            } else {
                amount = Math.max(amount,_votes[_totalIds[i]].voteinfos[account]);   
            }
        }
        return amount;
    }

    function validBalanceByProposal(uint256 proposal_id,address account) public view returns (uint256) {
        return balanceOf(account) - _votes[proposal_id].voteinfos[account];
    }

    function lockedBalanceOf(uint256 proposal_id,address account) public view returns (uint256) {
        return _votes[proposal_id].voteinfos[account];
    }
    function validBalanceOf(address account) public view returns (uint256) {
        require(balanceOf(account) >= maxLockedBalanceOf(account), "invalid balance,locked balance was wrong!");
        return balanceOf(account) - maxLockedBalanceOf(account) ;
    }

    function getAllVotes(uint256 proposal_id) public view returns(uint256) {
        return _votes[proposal_id].all;
    }
    
    function createProposal(uint256 proposal_id,uint256 beginNumber,uint256 endNumber) public {
        require(validBalanceOf(tx.origin) > 0,"create_proposal: the creator must have some token");
        require(endNumber > beginNumber,"endNumber must be Greater than beginNumber");
        
        if (!_votes[proposal_id].isused) {
            _totalIds.push(proposal_id);
            _votes[proposal_id].begin = beginNumber;
            _votes[proposal_id].end = endNumber;
            _votes[proposal_id].isused = true;
        }
        emit CreateProposal(proposal_id,tx.origin,beginNumber,endNumber);
    }
    function vote(uint256 proposal_id,uint256 amount) public {
        require(_votes[proposal_id].isused,"vote: the proposal must be used");
        require(validBalanceByProposal(proposal_id,tx.origin) >= amount,"base_coin: vote amount exceeds it's own");
        require(_votes[proposal_id].begin < block.timestamp,"vote: the proposal not yet started");
        require(_votes[proposal_id].end > block.timestamp,"vote: the proposal was expired");
        
        _votes[proposal_id].voteinfos[tx.origin] += amount;
        _votes[proposal_id].all += amount;
        emit VoteEvent(proposal_id,tx.origin,amount);
    }
    function cancelVote(uint256 proposal_id,uint256 amount) public {
        require(lockedBalanceOf(proposal_id,tx.origin) >= amount,"cancel_vote: vote amount exceeds it's own");
        require(_votes[proposal_id].end > block.timestamp,"vote: the proposal was expired");
        
        _votes[proposal_id].voteinfos[tx.origin] -= amount;
        _votes[proposal_id].all -= amount;
        emit CancelVote(proposal_id,tx.origin,amount);
    }
    function finishProposal(uint256 proposal_id,address[] memory accounts) public onlyRoot {
         for (uint256 i = 0; i < accounts.length; ++i) {
            _votes[proposal_id].voteinfos[accounts[i]] = 0;
        }
        emit FinishProposal(proposal_id,tx.origin,accounts);
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(validBalanceOf(_msgSender()) >= amount,"base_coin: transfer amount exceeds allowance");
        return ERC20.transfer(recipient,amount);
    }
   
    function transferFrom(address sender,address recipient,uint256 amount) public virtual override returns (bool) {
        require(validBalanceOf(sender) >= amount,"base_coin: transferFrom amount exceeds allowance");
        return ERC20.transferFrom(sender,recipient,amount);
    }
    function mint(address to, uint256 amount) public onlyRoot {
        _mint(to, amount);
    }
    function burn(address to, uint256 amount) public onlyRoot {
        _burn(to, amount);
    }
}

contract DaoSpace{
    using Address for address;
    using SafeMath for uint256;
    
    struct ProposalInfo {
        address creator;
        uint256 start;
        uint256 end;
        uint8 ptype;
        bool executed;
        bool canceled;
        bool voteFinish;
        uint256 value;
        bytes calldatas;
        string description;
        uint256 affirmative;
        uint256 dissenting;
        uint256 abstention;
        address[] voters;
    }
    struct baseRule {
        uint8 affirmative;
        uint8 dissenting;
        uint8 abstention;
    }
    struct rule {
        baseRule common;
        baseRule manage;
        baseRule invest;
    }
    // Dao name
    string _name;
    string _symbol;
    string _description;
    address public _owner;
    address public voteToken;
    address public _vault;
    
    rule daoRule;
    mapping(uint256 => ProposalInfo) proposals;
    uint256[] proposalsIDs;
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address creator,
        uint256 position,
        uint8 ptype,
        uint256 starttime,
        uint256 endtime,
        string description
    );
    event ProposalExecuted(uint256 proposalid);
    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_,
    string memory desp_,uint256 totalVote_,rule memory rule_) {
        _name = name_;
        _symbol = symbol_;
        _description = desp_;
        _owner = msg.sender;
        voteToken = address(new base_coin(name_,symbol_,totalVote_));
        base_coin(voteToken).transfer(msg.sender,totalVote_);
        init(rule_);
    }
    
    function init(rule memory r) internal {
        daoRule = r;
        
        _vault = address(new Vault(address(this),voteToken));
    }
    
    function getRule(uint8 ptype) public view returns (baseRule memory rule0) {
        if (ptype == 1) {
            // common 
            rule0 = daoRule.common;
        } else if (ptype == 2) {
            // manage
            rule0 = daoRule.manage;
        } else {
            // invest
            rule0 = daoRule.invest;
        }
    }
    function makeProposalId(address creator,uint256 pos,uint8 _ptype,string memory _desp,
    uint256 value, bytes memory calldatas) private view returns (uint256) {
        
        return uint256(keccak256(abi.encode(creator,pos,_ptype,value,calldatas,keccak256(bytes(_desp)))));
    }
    
    
    function createProposal(uint256 _start,uint256 _end,uint8 _ptype,string memory _desp,
    uint256 value, bytes memory calldatas) external returns (uint256) {
        require(block.timestamp < _end && _end > _start,"createProposal: wrong the begin-end timestamp");
        require(_ptype > 0 && _ptype <= 3, "createProposal: invalid proposal type");
        require(bytes(_desp).length <= 30, "description too long");
        
        uint256 pos = proposalsIDs.length;
        uint256 proposalid = makeProposalId(msg.sender,pos,_ptype,_desp,value,calldatas);
        ProposalInfo storage info = proposals[proposalid];
        if (info.ptype == 0) {
            info.creator = msg.sender;
            info.start = _start;
            info.end = _end;
            info.ptype = _ptype;
            info.executed = false;
            info.canceled = false;
            info.value = value;
            info.calldatas = calldatas;
            info.description = _desp;
            
            proposalsIDs.push(proposalid);
            base_coin(voteToken).createProposal(proposalid,_start,_end);
            emit ProposalCreated(proposalid,msg.sender,pos,_ptype,_start,_end,_desp);
            
        }
        return proposalid;
    } 
    
    function cancelProposal(uint256 proposalid) public {
        ProposalInfo storage info = proposals[proposalid];
        require(info.ptype != 0, "vote: the proposal not exsit");
        require(!info.executed && !info.canceled,"vote: the proposal finished or canceled");
        require(msg.sender == info.creator,"cancelProposal: only creator");
        
        info.canceled = true;
        base_coin(voteToken).finishProposal(proposalid,info.voters);
    }
    
    function vote(uint256 proposalid,uint256 amount,uint8 direction) public {
        require(direction>=1 && direction <=3,"vote: invalid direction");
        ProposalInfo storage info = proposals[proposalid];
        require(info.ptype != 0, "vote: the proposal not exsit");
        require(!info.voteFinish,"vote: finished");
        require(block.timestamp >= info.start && info.end >= block.timestamp,"vote: the proposal Expired or not started");
        require(!info.executed && !info.canceled,"vote: the proposal finished or canceled");
        
        base_coin(voteToken).vote(proposalid,amount);
        if (direction == 1) {
            info.affirmative += amount;
        } else if (direction == 2) {
            info.dissenting += amount;
        } else {
            info.abstention += amount;
        }
        
        info.voters.push(msg.sender);
        
        // Statistical proposal voting results
        baseRule memory rule0 = getRule(info.ptype);
        uint256 _total = base_coin(voteToken).totalSupply();
        if (info.abstention > _total.mul(rule0.abstention) / 100 || 
        info.dissenting > _total.mul(rule0.dissenting) / 100) {
            // the proposal will be canceled
            info.canceled = true;
        } else {
            if (info.affirmative >= _total.mul(rule0.affirmative) / 100) {
                // the proposal was passed
                info.voteFinish = true;
                base_coin(voteToken).finishProposal(proposalid,info.voters);
            }
        }
    }

    function executeProposal(uint256 proposalid) public {
        ProposalInfo storage info = proposals[proposalid];
        require(info.ptype != 0, "vote: the proposal not exsit");
        require(!info.executed && !info.canceled, "proposal: can not be execute");
        require(info.voteFinish, "proposal: can not be execute");
        
        info.executed = true;
        emit ProposalExecuted(proposalid);
        if (info.ptype == 3) {
            _executeByVault(proposalid);
        } else {
            _executeByDao(proposalid);
        }
    }
    ////////////////////////////////////////////////////////////////////
    function _executeByVault(uint256 proposalid) internal {
        ProposalInfo storage info = proposals[proposalid];
        string memory errorMessage = "DAO: call reverted without message";
        (bool success, bytes memory returndata) = _vault.call{value: info.value}(info.calldatas);
        Address.verifyCallResult(success, returndata, errorMessage);
    }
    function _executeByDao(uint256 proposalid) internal {
         ProposalInfo storage info = proposals[proposalid];
        string memory errorMessage = "DAO: call reverted without message";
        (bool success, bytes memory returndata) = address(this).call{value: info.value}(info.calldatas);
        Address.verifyCallResult(success, returndata, errorMessage);
    }

    // called by DAO self by calldata, first, the user will be invitation must be approve 
    // for `token` transferFrom by DAO.
    function addMemberByToken(address token,address to,uint256 amount0,uint256 amount1) public {
        require(msg.sender == address(this),"invalid sender");
        IERC20(token).transferFrom(to,_vault,amount0);
        base_coin(voteToken).mint(to,amount1);
    }
    function addMemberByNFT(address token,address to,uint256 tokenid,uint256 amount1) public {
        require(msg.sender == address(this),"invalid sender");
        IERC721(token).transferFrom(to,_vault,tokenid);
        base_coin(voteToken).mint(to,amount1);
    }

    function updateRule(uint8 _ptype,uint8 affirmative,uint8 dissenting,uint8 abstention) public {
         require(msg.sender == address(this),"invalid sender");
         require(_ptype > 0 && _ptype <= 3, "createProposal: invalid ptype");
         require(affirmative <= 100 && dissenting<100 && abstention<100,"invalid params");
         
         if (_ptype == 1) {
             // common
             daoRule.common.affirmative = affirmative;
             daoRule.common.dissenting = dissenting;
             daoRule.common.abstention = abstention;
         } else if (_ptype == 2) {
             // manage
             daoRule.manage.affirmative = affirmative;
             daoRule.manage.dissenting = dissenting;
             daoRule.manage.abstention = abstention;
         } else {
             daoRule.invest.affirmative = affirmative;
             daoRule.invest.dissenting = dissenting;
             daoRule.invest.abstention = abstention;
         }
    }
    
    function redeemByToken(address token,address to,uint256 amount0,uint256 amount1)public{
        //require(msg.sender == address(this),"invalid sender");
        IERC20(token).transferFrom(_vault,to,amount0);
        base_coin(voteToken).burn(to,amount1);
    }
    
    function redeemByNFT(address token,address to,uint256 amount0,uint256 amount1)public{
        //require(msg.sender == address(this),"invalid sender");
        IERC721(token).transferFrom(_vault,to,amount0);
        base_coin(voteToken).burn(to,amount1);
    }
    
    function getTime() public view returns (uint256){
        return block.timestamp;
    }
    
    function getTotalVotes(address user) public view returns (uint256){
        return base_coin(voteToken).balanceOf(user);
    }
    
    function getLockedVotesByProposal(uint256 proposal_id) public view returns (uint256){
        return base_coin(voteToken).lockedBalanceOf(proposal_id,msg.sender);
    }
    
    function getUnlockedVotes(address user) public view returns (uint256){
        return base_coin(voteToken).validBalanceOf(user);
    }
    
    function getAllVotesByProposal(uint256 proposal_id) public view returns(uint256) {
        return base_coin(voteToken).getAllVotes(proposal_id);
    }
    
    function getAllVotersByProposal(uint256 proposal_id) public view returns(address[] memory voters) {
        return proposals[proposal_id].voters;
    }
    
    function getProposalByID(uint256 proposal_id) public view returns (ProposalInfo memory info){
        return proposals[proposal_id];
    }
}