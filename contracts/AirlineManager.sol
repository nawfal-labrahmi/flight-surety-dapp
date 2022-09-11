pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract AirlineManager {

    using SafeMath for uint256;

    struct Airline {
        bool isRegistered;
        bool isFunded;
    }
    mapping(address => Airline) airlines; // Mapping for storing registered airlines
    
    address[] registeredAirlines; // Array of registered airlines
    
    // Used to implement multi-party consensus on airline registration
    struct AirlineRegistration {
        address[] registrators;
    }
    mapping(address => AirlineRegistration) registrationConsensus;


    /**
     * @dev Modifier that requires that registered airlines cannot participate in contract until they 
     *      submit required insurance funding
     */
    modifier requireFundedAirline(address account) {
        require(airlines[account].isFunded, "Airline did not submit insurance funding yet");
        _;
    }


    /**
     * @dev Gets whether an airline is registered
     *
     */      
    function isRegistered(address account) internal view returns(bool) {
        return airlines[account].isRegistered;
    }

    /**
     * @dev Gets whether an airline is registered and fully participant in the contract
     *
     */      
    function isFunded(address account) internal view returns(bool) {
        return airlines[account].isFunded;
    }

    /**
     * @dev Returns number of currently registered airlines
     *
     */      
    function getRegisteredNumber() internal view returns(uint) {
        return registeredAirlines.length;
    }

    /**
     * @dev Returns numbers of registrators of a given airline
     *
     */      
    function getConsensusRegistratorsNumber(address account) internal view returns(uint) {
        return registrationConsensus[account].registrators.length;
    }

    /**
     * @dev Returns registrator address of airline by index
     *
     */      
    function getConsensusRegistratorByIndex(address account, uint _i) internal view returns(address) {
        return registrationConsensus[account].registrators[_i];
    }

    /**
     * @dev Add an airline to the list of consensus registrators of a given airline
     *
     */      
    function addConsensusRegistrator(address account, address from) internal {
        registrationConsensus[account].registrators.push(from);
    }

    /**
     * @dev Register the first airline on contract deployment.
     *      
     */
    function registerFirst(address account) internal {
        registerNew(account);
    }

    /**
     * @dev Register a new (not funded yet) airline
     *      
     */
    function registerNew(address account) internal {
        airlines[account] = Airline({                            
                                    isRegistered: true,
                                    isFunded: false
                                });
        registeredAirlines.push(account);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *      Requirement: Airline can be registered, but does not participate in contract until it submits funding of 10 ether 
     *
     */   
    function fund(address account) internal {        
        airlines[account].isFunded = true;
    }
    
}