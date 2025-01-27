### Reactive Network Cross Chain Lending 

This code example demonstrates how Reactive Network can be used for a cross chain lending protocol.
Deploy the `Collateral.sol` contract on an origin chain to manage user's deposits. Deploy the `Loan.sol`
contract on the destination chain to manage user's issuing and repaying of loans. Finally, deploy the
`ReactiveLoan.sol` which subscribes and monitors events on both the origin and destination chains and
triggers callbacks when appropriate. See the list of available origin and destination chains in the next section.

## Origin and Destination Chains
[available origin and destination chains](https://dev.reactive.network/origins-and-destinations)

## License

MIT

This is not production ready software and has not been audited, use at your own risk. 
I'm not liable for any losses incurred during use of this code.