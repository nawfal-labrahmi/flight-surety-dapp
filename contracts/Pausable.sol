pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

/*
* Allows pausing a smart contract - Operational Status Control implementation
* Contract operations can be protected behind the requireOperationalContract modifier.
* Only contract owner can pause/resume its execution.
*/
contract Pausable is Ownable {
    
    bool private operational = true;

    modifier requireOperationalContract() {
        require(operational, "Contract must be operational");
        _;
    }

    function isOperational() public view returns(bool) {
        return operational;
    }

    function setOperationalStatus(bool status) public onlyOwner {
        require(status != operational, "New status must be different from the current status");
        operational = status;
    }
}