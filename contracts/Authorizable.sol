pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract Authorizable is Ownable {

    mapping (address => bool) private authorizedContracts;

    modifier onlyAuthorizedContract() {
        require(authorizedContracts[msg.sender], "Caller contract is not authorized");
        _;
    }

    constructor() Ownable() internal {
        authorizeContract(msg.sender);
    }

    function authorizeContract(address account) public onlyOwner {
        authorizedContracts[account] = true;
    }

    function deauthorizeContract(address account) public onlyOwner {
        delete authorizedContracts[account];
    }

    function isAuthorized(address account) public view returns(bool) {
        return authorizedContracts[account];
    }
}