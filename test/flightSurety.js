const Test = require('../config/testConfig.js');
const OracleMock = require('./oracleMock');
const BigNumber = require('bignumber.js');

const FlightSuretyApp = artifacts.require('FlightSuretyApp');
const FlightSuretyData = artifacts.require('FlightSuretyData');
const truffleAssert = require('truffle-assertions');

contract('FlightSurety', (accounts) => {
    let appContract;
    let dataContract;

    const [
        airline1,
        airline2,
        airline3,
        airline4,
        airline5,
        passenger1,
        passenger2,
    ] = accounts;

    const testFlight = {
        flightNumber: 'TEST123',
        timestamp: Date.parse('01 Jan 2019 09:00:00 GMT'),
    };

    beforeEach(async () => {
        appContract = await FlightSuretyApp.deployed();
    });

    describe('Contract specifications', () => {

        var config;
        before('setup contract', async () => {
            config = await Test.Config(accounts);
            await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
        });

        it(`Contract is initially operational`, async function () {
            let status = await config.flightSuretyData.isOperational.call();
            assert.equal(status, true, "Incorrect initial operating status value");
        });
        
        it(`Only contract owner account can update operating status - non contract owner test`, async () => {
            let accessDenied = false;
            try {
                await config.flightSuretyData.setOperationalStatus(false, { from: config.testAddresses[2] });
            }
            catch(e) {
                accessDenied = true;
            }
            assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
        });
    
        it(`Only contract owner account can update operating status - contract owner test`, async () => {
            let accessDenied = false;
            try {
                await config.flightSuretyData.setOperationalStatus(false);
            }
            catch(e) {
                accessDenied = true;
            }
            assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
        });
    
        it(`Access to functions using requireOperationalContract is blocked when operating status is false`, async () => {
            await config.flightSuretyData.setOperationalStatus(false);
    
            let reverted = false;
            try {
                await config.flightSurety.setTestingMode(true);
            }
            catch(e) {
                reverted = true;
            }
            assert.equal(reverted, true, "Access not blocked for requireOperationalContract");      
    
            await config.flightSuretyData.setOperationalStatus(true);
        });
    }),

    describe('Airline specifications', () => {
        beforeEach(async () => {
            dataContract = await FlightSuretyData.deployed();
        });

        it('First airline is registered on contract deployment', async () => {
            const registeredCount = await dataContract.getRegisteredAirlinesNumber();
            assert.equal(registeredCount.toNumber(), 1);
        });

        it('Only existing airline may register a new airline until there are at least four airlines registered', async () => {
            let tx;
            // Registration request from registered airline passes
            tx = await appContract.registerAirline(airline2, { from: airline1 });
            truffleAssert.eventEmitted(tx, 'AirlineDirectRegistration', event => event.account === airline2);

            // Registration request from not registered airline fails
            try {
                await appContract.registerAirline(airline3, { from: airline5 });
                throw new Error('unreachable error');
            } catch (error) {
                assert.match(error.message, /Airline account must be registered & fully funded/);
            }

            // Registration request from airline3
            tx = await appContract.registerAirline(airline3, { from: airline2 });
            truffleAssert.eventEmitted(tx, 'AirlineDirectRegistration', event => event.account === airline3);

            // Registration request from airline4
            tx = await appContract.registerAirline(airline4, { from: airline3 });
            truffleAssert.eventEmitted(tx, 'AirlineDirectRegistration', event => event.account === airline4);

            // First 4 airlines are directly registered without consensus
            const registeredCount = await dataContract.getRegisteredAirlinesNumber();
            assert.equal(registeredCount.toNumber(), 4);
        });

        it('Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async () => {
            let tx;
            let registeredCount;

            // Airline not directly registered, but just voted
            tx = await appContract.registerAirline(airline5, { from: airline1 });
            truffleAssert.eventNotEmitted(tx, 'AirlineDirectRegistration', event => event.account === airline5);
            truffleAssert.eventEmitted(tx, 'AirlineConsensusVoted', event => (
                event.account === airline5 && event.votesCount.toNumber() === 1
            ));

            // Number of registered airlines unchanged
            registeredCount = await dataContract.getRegisteredAirlinesNumber();
            assert.equal(registeredCount.toNumber(), 4);

            tx = await appContract.registerAirline(airline5, { from: airline2 });
            truffleAssert.eventEmitted(tx, 'AirlineConsensusVoted', event => (
                event.account === airline5 && event.votesCount.toNumber() === 2
            ));

            // Registration consensus threshold of 50% now is attained
            truffleAssert.eventEmitted(tx, 'AirlineConsensusRegistration', event => event.account === airline5);

            // Number of registered airlines incremented
            registeredCount = await dataContract.getRegisteredAirlinesNumber();
            assert.equal(registeredCount.toNumber(), 5);
        });

        it('Airline can be registered but does not participate in contract until it submits funding of 10 ether', async () => {
            let funded;

            funded = await appContract.isFunded.call(airline1);
            assert.equal(funded, false);

            const amount = web3.utils.toWei('10', 'ether');
            const tx = await appContract.fundAirline({ from: airline1, value: amount });
            truffleAssert.eventEmitted(tx, 'AirlineFunded', (event) => {
                const deposit = web3.utils.fromWei(event.deposit.toString(), 'ether');
                return event.account === airline1 && deposit === '10';
            });

            funded = await appContract.isFunded.call(airline1);
            assert.equal(funded, true);
        });
    });

    describe('Passenger specifications', () => {
        const premium = web3.utils.toWei('1', 'ether');
        const payout = web3.utils.toWei('1.5', 'ether');

        let oracles;

        before(async () => {
            // Register the flight
            const { flightNumber, timestamp } = testFlight;
            await appContract.registerFlight(flightNumber, timestamp, { from: airline1 });

            // Instantiate the mock oracles
            oracles = accounts.slice(10, 30).map(account => new OracleMock(account));

            // Register oracles and get their indexes
            const registrationFee = web3.utils.toWei('1', 'ether');
            await Promise.all(oracles.map(oracle => (
                appContract.registerOracle({ from: oracle.address, value: registrationFee })
                    .then(() => appContract.getOracleIndexes({ from: oracle.address }))
                    .then((indexes) => {
                        oracle.setIndexes(indexes);
                    })
            )));
        });

        it('Passengers may pay up to 1 ether for purchasing flight insurance', async () => {
            // A passenger can pay 1 ether
            const { flightNumber, timestamp } = testFlight;
            const tx = await appContract.buyInsurance(flightNumber, timestamp, {
                from: passenger1,
                value: premium,
            });
            truffleAssert.eventEmitted(tx, 'BuyInsurance', event => (
                event.account === passenger1
                && event.flight === flightNumber
                && event.timestamp.toNumber() === timestamp
                && event.amount.toString() === premium
            ));

            // A passenger cannot pay more than 1 ether
            try {
                await appContract.buyInsurance(flightNumber, timestamp, {
                    from: passenger2,
                    value: web3.utils.toWei('2', 'ether'),
                });
                throw new Error('unreachable error');
            } catch (error) {
                assert.match(error.message, /Insurance fee must be greater than 0 and lower or equal to 1 ether/);
            }
        });

        it('If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid and can withdraw insurance payout', async () => {
            // Oracle request emitted when fetching the flight status
            let requestIndex;
            const { flightNumber, timestamp } = testFlight;

            const tx = await appContract.fetchFlightStatus(
                flightNumber,
                timestamp,
                { from: passenger1 },
            );
            truffleAssert.eventEmitted(tx, 'OracleRequest', (event) => {
                requestIndex = event.index.toNumber();
                return (
                    event.flight === flightNumber
                    && event.timestamp.toNumber() === timestamp
                );
            });

            // Valid oracles submit a Late Airline flight status
            const statusCode = 20; // STATUS_CODE_LATE_AIRLINE = 20
            const oraclesAllowToSubmit = oracles.filter(oracle => oracle.hasIndex(requestIndex));
            await Promise.all(oraclesAllowToSubmit.slice(0, 3).map(oracle => (
                appContract.submitOracleResponse(
                    requestIndex,
                    flightNumber,
                    timestamp,
                    statusCode,
                    { from: oracle.address },
                )
            )));

            // Passenger can withdraw insurance payout
            const balanceBefore = await web3.eth.getBalance(passenger1);

            await appContract.withdrawPayout(
                flightNumber,
                timestamp,
                { from: passenger1, gasPrice: 0 },
            );

            const balanceAfter = await web3.eth.getBalance(passenger1);

            assert.equal(
                Number(balanceAfter) - Number(balanceBefore),
                Number(payout),
            );
        });
    });
});
