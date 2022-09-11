pragma solidity ^0.4.25;

import "./Pausable.sol";
import "./Authorizable.sol";
import "./AirlineManager.sol";
import "./FlightManager.sol";
import "./InsuranceManager.sol";

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData is Pausable, Authorizable, AirlineManager, FlightManager, InsuranceManager {
    
    using SafeMath for uint256;

    address private contractOwner;


    constructor() Authorizable() public {
        contractOwner = msg.sender;
        AirlineManager.registerNew(msg.sender); // First airline is registered on contract deployment
    }


    /********************************************************************************************/
    /*                                       AIRLINES                                           */
    /********************************************************************************************/

    /**
     * @dev Register a new (not funded yet) airline
     *      
     */
    function registerNewAirline(address account) external requireOperationalContract onlyAuthorizedContract {
        AirlineManager.registerNew(account);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */   
    function fundAirline(address account) external requireOperationalContract onlyAuthorizedContract {
        AirlineManager.fund(account);
    }

    /**
     * @dev Gets whether an airline is registered
     *
     */      
    function isRegisteredAirline(address account) external view requireOperationalContract onlyAuthorizedContract returns(bool) {
        return AirlineManager.isRegistered(account);
    }

    /**
     * @dev Gets number of registered airlines
     *
     */      
    function getRegisteredAirlinesNumber() external view requireOperationalContract onlyAuthorizedContract returns(uint) {
        return AirlineManager.getRegisteredNumber();
    }

    /**
     * @dev Returns numbers of registrators of a given airline
     *
     */      
    function getAirlineConsensusRegistratorsNumber(address account) external view requireOperationalContract onlyAuthorizedContract returns(uint) {
        return AirlineManager.getConsensusRegistratorsNumber(account);
    }

    /**
     * @dev Returns registrator address of airline by index
     *
     */      
    function getAirlineConsensusRegistratorByIndex(address account, uint _i) external view requireOperationalContract onlyAuthorizedContract returns(address) {
        return AirlineManager.getConsensusRegistratorByIndex(account, _i);
    }

    /**
     * @dev Add an airline to the list of consensus registrators of a given airline
     *
     */      
    function addAirlineConsensusRegistrator(address account, address from) external requireOperationalContract onlyAuthorizedContract {
        return AirlineManager.addConsensusRegistrator(account, from);
    }

    /**
     * @dev Gets whether an airline is registered and fully participant in the contract
     *
     */      
    function isFundedAirline(address account) external view requireOperationalContract onlyAuthorizedContract returns(bool) {
        return AirlineManager.isFunded(account);
    }
    
    
    /********************************************************************************************/
    /*                                       FLIGHTS                                            */
    /********************************************************************************************/

    function registerFlight(bytes32 flightKey, address airline) external requireOperationalContract onlyAuthorizedContract {
        FlightManager.register(flightKey, airline);
    }

    function isRegisteredFlight(bytes32 flightKey) external view requireOperationalContract onlyAuthorizedContract returns(bool) {
        return FlightManager.isRegistered(flightKey);
    }

    function isPayoutFlight(bytes32 flightKey) external view requireOperationalContract onlyAuthorizedContract returns(bool) {
        return FlightManager.isPayoutStatus(flightKey);
    }

    function processFlightStatus(bytes32 flightKey, uint8 statusCode) external requireOperationalContract onlyAuthorizedContract {
        FlightManager.changeStatus(flightKey, statusCode);
    }


    /********************************************************************************************/
    /*                                       INSURANCE                                          */
    /********************************************************************************************/

    /**
     * @dev Buy insurance for a flight as a passenger
     *
     */   
    function buyInsurance(bytes32 insuranceKey, bytes32 flightKey, address insuree, uint amount) external requireOperationalContract onlyAuthorizedContract {
        InsuranceManager.buy(insuranceKey, flightKey, insuree, amount);
    }

    /**
     *  @dev Credit a payout to an insured passenger
     *
     */
    function creditInsurees(bytes32 flightKey) external requireOperationalContract onlyAuthorizedContract {
        InsuranceManager.credit(flightKey);
    }

    /**
     *  @dev Returns the credit balance of a given insuree
     *
     */
    function getInsureeBalance(address insuree) external view requireOperationalContract onlyAuthorizedContract {
        InsuranceManager.getBalance(insuree);
    }

    /**
     *  @dev Transfer eligible payout funds to an insured passenger
     *
     */
    function withdrawPayout(address insuree, uint256 amount) external requireOperationalContract onlyAuthorizedContract {
        InsuranceManager.withdraw(insuree, amount);
    }

}

