pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";



contract base_coin is ERC20,ERC20Burnable {
    
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
    function lockedBalanceOf(uint256 proposal_id,address account) public view returns (uint256) {
        return _votes[proposal_id].voteinfos[account];
    }
    function validBalanceOf(address account) public view returns (uint256) {
        require(balanceOf(account) >= maxLockedBalanceOf(account), "invalid balance,locked balance was wrong!");
        return balanceOf(account) - maxLockedBalanceOf(account) ;
    }

    function getAllVotes(uint256 proposal_id) public returns(uint256) {
        return _votes[proposal_id].all;
    }
    
    function createProposal(uint256 proposal_id,uint256 beginNumber,uint256 endNumber) public {
        require(validBalanceOf(_msgSender()) > 0,"create_proposal: the creator must have some token");
        require(endNumber > beginNumber,"endNumber must be Greater than beginNumber");
        
        if (!_votes[proposal_id].isused) {
            _totalIds.push(proposal_id);
            _votes[proposal_id].begin = beginNumber + block.number;
            _votes[proposal_id].end = endNumber + block.number;
            _votes[proposal_id].isused = true;
        }
        emit CreateProposal(proposal_id,_msgSender(),beginNumber,endNumber);
    }
    function vote(uint256 proposal_id,uint256 amount) public {
        require(_votes[proposal_id].isused,"vote: the proposal must be used");
        require(maxLockedBalanceOf(_msgSender()) >= amount,"base_coin: vote amount exceeds it's own");
        require(_votes[proposal_id].begin < block.number,"vote: the proposal not yet started");
        require(_votes[proposal_id].end > block.number,"vote: the proposal was expired");
        
        _votes[proposal_id].voteinfos[_msgSender()] += amount;
        _votes[proposal_id].all += amount;
        emit VoteEvent(proposal_id,_msgSender(),amount);
    }
    function cancelVote(uint256 proposal_id,uint256 amount) public {
        require(lockedBalanceOf(proposal_id,_msgSender()) >= amount,"cancel_vote: vote amount exceeds it's own");
        require(_votes[proposal_id].end > block.number,"vote: the proposal was expired");
        
        _votes[proposal_id].voteinfos[_msgSender()] -= amount;
        _votes[proposal_id].all -= amount;
        emit CancelVote(proposal_id,_msgSender(),amount);
    }
    function finishProposal(uint256 proposal_id,address[] memory accounts) public onlyRoot {
         for (uint256 i = 0; i < accounts.length; ++i) {
            _votes[proposal_id].voteinfos[accounts[i]] = 0;
        }
        emit FinishProposal(proposal_id,_msgSender(),accounts);
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
     // function approve(address spender, uint256 amount) public virtual override returns (bool) {
        
    // }
}