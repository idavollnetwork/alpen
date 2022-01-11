# alpen


## deploy

| parameter   | type      | comment |
| ----------- | ----------| ------- |
| NAME        | string    | the name of the project |
| SYMBOL      | string    | the symbol of the token |
| DESP        | string    | the description of the project |
| TOTALVOTE   | uint256   | the number of votes initially owned by the creator |
| RULE        | tuple     | percentage of three types of successes, failures, waivers |

- example:
```
name_: daospace
symbol_: A
desp_: good description
totalVote_: 100
rule_: [[80,80,80],[80,80,80],[80,80,80]]
```

## flow

### 1.create proposal


| parameter   | type      | comment |
| ----------- | ----------| ------- |
| START       | uint256   | started time |
| END         | uint256   | ended time |
| PTYPE       | uint8     | the type of proposal |
| DESP        | string    | the description of the proposal |
| VALUE       | uint256   | the token number you need to call calldata |
| CALLDATAS   | bytes     | The input parameters for contract execution |

- example:
```
_start: 1635753248
_end: 1635753448
_ptype: 1
_desp: good description
value: 0 
calldatas: 0x557ed1ba
```

Start by generating calldata with our contract. 
Use the remix to call our public function to create a transaction.
Notify,The transaction is not actually for sending, and even if it does, it will fail.
Copy input parameter(i.e. calldata)of the transaction.

The following function are executed by contract when vote pass:

- addMemberByToken

- addMemberByNFT

- updateRule

- redeemByToken

- redeemByNFT

Call function getTime() to get timestamp. Input started timestamp and ended timestamp, choose proposal type(1 is common, 2 is manage, 3 is investment),
add about description (length <= 30), if calldata need to token, fill number in value.

Write above all parameters, we can create a proposal.

### 2.vote

| parameter   | type      | comment |
| ----------- | ----------| ------- |
| PROPOSALID  | uint256   | proposal ID from function createPrposal()|
| AMOUNT      | uint256   | vote number |
| DIRECTION   | uint8     | voted type: 1 is affirmative, 2 is dissenting, 3 is abstention |

- example:
```
proposalid: 27515957333565846176385035850353494069478654637169617643988720204340334849395
amount: 10
direction: 1
```

### 3.execute proposal

| parameter   | type      | comment |
| ----------- | ----------| ------- |
| PROPOSALID  | uint256   | proposal ID from function createPrposal()|

- example:
```
proposalid: 27515957333565846176385035850353494069478654637169617643988720204340334849395
```

When vote pass in terms of voted finish, the function executeProposal() is executed.

### 4.finish proposal

| parameter   | type      | comment |
| ----------- | ----------| ------- |
| PROPOSALID  | uint256   | proposal ID from function createPrposal()|
| ACCOUNTS    | uint256   | The addresses of the voters|

- example:
```
proposalid: 27515957333565846176385035850353494069478654637169617643988720204340334849395
accounts: ["0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"]
```
When user cast votes, his votes will be locked in this proposal. Only vote finish, his votes are unlocked.
The unlocked votes influence redeem asset. Call function finishProposal() can unlocked them After voting executed.