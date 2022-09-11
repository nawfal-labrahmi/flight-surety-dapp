# Project Overview: FlightSurety

Flight Surety is a Decentralized App with autonomous smart contracts and Oracles. It showcases a flight surety use case: Airlines register and fund a flight delay insurance service in the Dapp, passengers can buy said insurance and get an insurance credit payout when applicable that they can withdraw securely, and the autonomous smart contract relies on a cluster of independent Oracles to get flight information.

The Dapp is structured in the following manner: 
* A web frontend app handles the interactions with end users to buy insurance, display flight info and withdraw payouts
* An Ethereum smart contract handles the business logic and the data
* A Node.js app server emulates the external Oracles behavior

This was realized as part of the Udacity Blockchain Developer Nanodegree: https://www.udacity.com/course/blockchain-developer-nanodegree--nd1309

# Project Requirements

## Architecture/Security
* Smart contract code is separated into multiple contracts: FlightSuretyData for data persistence and FlightSuretyApp for app logic and oracles code
* A server app is created for simulating oracle behavior
* Operational status control is implemented
* Contract functions “fail fast” by having a majority of “require()” calls at the beginning of function body

## Airlines
* First airline is registered when contract is deployed
* Only existing airline may register a new airline until there are at least four airlines registered
* Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines
* Airline can be registered, but does not participate in contract until it submits funding of 10 ether

## Passengers
* Passengers can choose from a fixed list of flight numbers and departures that are defined in the Dapp client
* Passengers may pay up to 1 ether for purchasing flight insurance.
* If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid
* Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout
* Insurance payouts are not sent directly to passenger’s wallet

## Oracles
* Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory
* Update flight status requests from client Dapp
* Server will loop through all registered oracles, identify those oracles for which the OracleRequest event applies, and respond by calling into FlightSuretyApp contract with random status code


# Install

This repository contains Smart Contract code in Solidity (bootstrapped using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

# Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

# Develop Server

`npm run server`
`truffle test ./test/oracles.js`

# Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


# Dependencies

* Truffle v5.0.1
* Solidity v0.4.25
* Node v16.15.1
* Web3.js v1.7.4
* Express.js v4.16.4
* Truffle assertions v0.9.2
* Truffle HDWallet Provider v2.0.13
* OpenZeppelin Solidity v1.10.0
