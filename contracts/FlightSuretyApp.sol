pragma solidity ^0.4.25;

import "./Pausable.sol";
import "./FlightSuretyData.sol";

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyApp is Pausable {
    
    using SafeMath for uint256;

    uint private constant DIRECT_REGISTRATORS_LIMIT = 4;
    uint private constant MAX_INSURANCE_FEE = 1 ether;
    uint public constant AIRLINE_FUNDING_AMOUNT = 10 ether;
    address private contractOwner;

    FlightSuretyData dataContract;

    event AirlineDirectRegistration(address indexed account);
    event AirlineConsensusVoted(address indexed account, uint votesCount);
    event AirlineConsensusRegistration(address indexed account);
    event AirlineFunded(address indexed account, uint deposit);

    event FlightRegistered(string flight, uint timestamp, address airline);
    event FlightStatusInfo(string flight, uint timestamp, uint8 status);

    event BuyInsurance(address indexed account, string flight, uint timestamp, uint amount);

    event OracleRequest(string flight, uint timestamp, uint8 indexed index);
    event OracleReport(string flight, uint timestamp, uint8 status);

    constructor(address _dataContractAddress) public {
        contractOwner = msg.sender;
        dataContract = FlightSuretyData(_dataContractAddress);
    }
    

    modifier requireNonContract() {
        require(msg.sender == tx.origin, "Contracts are not authorized as caller");
        _;
    }

    modifier requireRegisteredAirline(address account) {
        require(dataContract.isRegisteredAirline(account), "Airline account must be registered");
        _;
    }

    modifier requireFundedAirline(address account) {
        require(dataContract.isFundedAirline(account), "Airline account must be registered & fully funded");
        _;
    }

    
    /********************************************************************************************/
    /*                                       AIRLINES                                           */
    /********************************************************************************************/ 

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */   
    function registerAirline(address account) public requireOperationalContract requireFundedAirline(msg.sender) {
        require(!dataContract.isRegisteredAirline(account), "Airline to be registered is already registered.");
        address from = msg.sender;

        // Only existing airline may register a new airline until there are at least four airlines registered
        uint registerdAirlinesNumber = _getRegisteredAirlinesNumber();
        
        if (registerdAirlinesNumber <= DIRECT_REGISTRATORS_LIMIT) {
            dataContract.registerNewAirline(account);
            emit AirlineDirectRegistration(account);
        }

        // Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines
        bool isDuplicate = false;
        for (uint i = 0; i < dataContract.getAirlineConsensusRegistratorsNumber(account); i++) {
            if (dataContract.getAirlineConsensusRegistratorByIndex(account, i) == from) {
                isDuplicate = true;
                break;
            }
        }
        require(!isDuplicate, "Caller airline account has already called this function, for this to-be-registered airline account");
        dataContract.addAirlineConsensusRegistrator(account, from);
        uint votersNumber = dataContract.getAirlineConsensusRegistratorsNumber(account);
        emit AirlineConsensusVoted(account, votersNumber);

        if (votersNumber >= _getConsensusThreshold()) {
            dataContract.registerNewAirline(account);
            emit AirlineConsensusRegistration(account);
        }
    }

    /**
     * @dev Airlines must submit a funding after being registered in order to be allowed to participate in contract
     *
     */  
    function fundAirline() public payable requireOperationalContract requireRegisteredAirline(msg.sender) {
        address account = msg.sender;
        uint amount = msg.value;
        
        require(amount >= AIRLINE_FUNDING_AMOUNT, "Insufficient funding amount");
        
        dataContract.fundAirline(account);
        emit AirlineFunded(account, amount);
    }

    function _getRegisteredAirlinesNumber() private view returns(uint) {
        return dataContract.getRegisteredAirlinesNumber();
    }

    function _getConsensusThreshold() private view returns(uint) {
        return _getRegisteredAirlinesNumber().div(2);
    }

    
    /********************************************************************************************/
    /*                                       FLIGHTS                                            */
    /********************************************************************************************/

    /**
     * @dev Register a future flight for insuring.
     */  
    function registerFlight(string memory flight, uint timestamp) public requireOperationalContract requireFundedAirline(msg.sender) {
        address airline = msg.sender;
        bytes32 flightKey = _generateKey(airline, flight, timestamp);
        dataContract.registerFlight(flightKey, airline);
        emit FlightRegistered(flight, timestamp, airline);
    }

    /**
     * @dev Generate a request for oracles to fetch flight information
     */
    function fetchFlightStatus(address airline, string flight, uint256 timestamp) public requireOperationalContract {
        uint8 index = generateRandomIndex(msg.sender);

        bytes32 oracleRequestKey = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[oracleRequestKey] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    /********************************************************************************************/
    /*                                       INSURANCE                                          */
    /********************************************************************************************/

    /**
     * @dev Allows passengers to by insurance for a given flight
     */
    function buyInsurance(address airline, string flight, uint timestamp) public payable requireOperationalContract requireFundedAirline(airline) requireNonContract {
        require(msg.value > 0 && msg.value <= MAX_INSURANCE_FEE, "Insurance fee must be greater than 0 and lower or equal to 1 ether");

        bytes32 flightKey = _generateKey(airline, flight, timestamp);
        require(dataContract.isRegisteredFlight(flightKey), "The requested flight must be registered");

        bytes32 insuranceKey = _generateKey(msg.sender, flight, timestamp);
        dataContract.buyInsurance(insuranceKey, flightKey, msg.sender, msg.value);

        emit BuyInsurance(msg.sender, flight, timestamp, msg.value);
    }

    /**
     * @dev Allows passengers to withdraw any credited amount due to insurance payout
     */
    function withdrawPayout(uint256 amount) public requireOperationalContract requireNonContract {
        dataContract.withdrawPayout(msg.sender, amount);
    }

    
    /********************************************************************************************/
    /*                                       ORACLES                                            */
    /********************************************************************************************/

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable {
        require(msg.value >= REGISTRATION_FEE, "Insufficient oracle registration fee");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    // TODO is this useful?
    function getMyIndexes() view external returns(uint8[3]) {
        require(oracles[msg.sender].isRegistered, "Caller must be a registered oracle");

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string flight, uint256 timestamp, uint8 statusCode) external {
        require(_isMatchingOracleIndex(index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            bytes32 flightKey = _generateKey(airline, flight, timestamp);
            dataContract.processFlightStatus(flightKey, statusCode);

            if (dataContract.isPayoutFlight(flightKey)) {
                dataContract.creditInsurees(flightKey);
            }
        }
    }

    function _isMatchingOracleIndex(uint8 index) view private returns(bool) {
        return 
            (oracles[msg.sender].indexes[0] == index) || 
            (oracles[msg.sender].indexes[1] == index) || 
            (oracles[msg.sender].indexes[2] == index);
    }

    function _generateKey(address account, string flight, uint256 timestamp) pure private returns(bytes32) {
        return keccak256(abi.encodePacked(account, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = generateRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = generateRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = generateRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
