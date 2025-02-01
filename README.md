# EventSphere DAO

A decentralized autonomous organization (DAO) platform built on Stacks for managing large-scale events. EventSphere enables decentralized event planning, ticket sales, revenue sharing, and governance decisions.

## Features
- Create and manage events with configurable parameters
- Issue and sell event tickets as NFTs
- DAO governance for event decisions
- Advanced Revenue Sharing System:
    - Configurable revenue splits between organizers, DAO, and stakeholders
    - Staking mechanism for stakeholders
    - Automated revenue distribution
- Proposal creation and voting system

## Getting Started
1. Clone this repository
2. Install dependencies with `clarinet install`
3. Run tests with `clarinet test`

## Contract Functions
- create-event: Create a new event with revenue sharing parameters
- buy-ticket: Purchase a ticket for an event
- stake-stx: Stake STX to become a stakeholder
- claim-revenue-share: Claim revenue share for stakeholders
- create-proposal: Create a governance proposal
- vote-on-proposal: Vote on an active proposal

## Revenue Sharing System
The platform implements a flexible revenue sharing model where event proceeds are automatically distributed between:
- Event organizers
- DAO treasury
- Stakeholders (STX stakers)

Revenue shares are configured during event creation and automatically distributed after the event concludes.
