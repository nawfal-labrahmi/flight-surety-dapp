pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/ReentrancyGuard.sol";

contract InsuranceManager is ReentrancyGuard {

    using SafeMath for uint256;

    struct Insurance {
        address insuree;
        uint256 amount;
        bool credited; // Whether insurance amount has been credited already
    }

    mapping(bytes32 => Insurance) private insurances; // insurances by insurance key
    mapping (bytes32 => bytes32[]) private flightInsurances; // insurance keys by flight key
    mapping (address => uint256) private insureeBalances; // insurance balance by insuree address


    /**
     * @dev Allows passengers to buy an insurance for a given flight
     *
     */   
    function buy(bytes32 insuranceKey, bytes32 flightKey, address insuree, uint amount) internal {
        require(insurances[insuranceKey].amount == 0, "This insurance has already been sold");
        
        insurances[insuranceKey] = Insurance(insuree, amount, false);
        flightInsurances[flightKey].push(insuranceKey);
    }

    /**
     * @dev Returns the insurance amount for a given insurance
     *
     */
    function getInsuranceAmount(bytes32 insuranceKey) internal view returns(uint) {
        return insurances[insuranceKey].amount;
    }

    /**
     * @dev Returns the credit balance of a given insuree
     *
     */
    function getBalance(address insuree) internal view returns(uint256) {
        return insureeBalances[insuree];
    }

    /**
     *  @dev Credits payouts to insurees
     *
     */
    function credit(bytes32 flightKey) internal {
        for (uint i=0; i < flightInsurances[flightKey].length; i++) {
            Insurance storage insurance = insurances[flightInsurances[flightKey][i]];
            if (insurance.credited == false) {
                _creditInsuree(insurance, _calculatedAmountToBeCredited(insurance.amount));
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     */
    function withdraw(address insuree, uint256 amount) internal nonReentrant {
        require(address(this).balance >= amount, "Withdrawal cannot exceed funds currently available on the contract to");
        require(insureeBalances[insuree] <= amount, "Withdrawal cannot exceed the current balance of the requesting insuree");
        
        address payableInsuree = address(uint160(insuree));
        uint256 availableBalance = insureeBalances[insuree];
        uint256 newBalance = availableBalance.sub(amount);
        
        insureeBalances[insuree] = newBalance;
        payableInsuree.transfer(amount);
    }

    function _calculatedAmountToBeCredited(uint256 insuranceAmount) private pure returns(uint256) {
        return insuranceAmount.mul(3).div(2);
    }

    function _creditInsuree(Insurance storage insurance, uint256 amount) private {
        insurance.credited = true;
        insureeBalances[insurance.insuree] = insureeBalances[insurance.insuree].add(amount).add(insurance.amount);
    }

}