pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightManager {

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    function register(bytes32 flightKey, address airline) internal {
        flights[flightKey] = Flight(true, STATUS_CODE_UNKNOWN, now, airline);
    }

    function isRegistered(bytes32 flightKey) internal view returns(bool) {
        return flights[flightKey].isRegistered;
    }

    function changeStatus(bytes32 flightKey, uint8 statusCode) internal {
        require(_isValidStatusCode(statusCode), "Invalid statusCode");

        flights[flightKey].statusCode = statusCode;
        flights[flightKey].updatedTimestamp = now;
    }

    function isPayoutStatus(bytes32 flightKey) internal view returns(bool) {
        uint8 statusCode = flights[flightKey].statusCode;
        return (
            statusCode == STATUS_CODE_LATE_AIRLINE ||
            statusCode == STATUS_CODE_LATE_TECHNICAL
        );
    }

    function _isValidStatusCode(uint8 statusCode) private pure returns(bool) {
        return (
            statusCode == STATUS_CODE_UNKNOWN ||
            statusCode == STATUS_CODE_ON_TIME ||
            statusCode == STATUS_CODE_LATE_AIRLINE ||
            statusCode == STATUS_CODE_LATE_WEATHER ||
            statusCode == STATUS_CODE_LATE_TECHNICAL ||
            statusCode == STATUS_CODE_LATE_OTHER
        );
    }

}