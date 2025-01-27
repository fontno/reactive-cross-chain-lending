// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {AbstractReactive} from "../lib/reactive-lib/src/abstract-base/AbstractReactive.sol";
import {ISystemContract} from "../lib/reactive-lib/src/interfaces/ISystemContract.sol";

/// @title ReactiveLoan.sol
/// @author Brian Fontenot
/// @notice Reactive Contract to subscribe and emit callbacks to the origin and destination chains
contract ReactiveLoan is IReactive, AbstractReactive {

    event Event(
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 indexed topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes data,
        uint256 counter
    );

    // @Dev Topic 0 derived by keccak256("Deposit(address,address,uint256,uint256)")
    uint256 private constant DEPOSIT_TOPIC = 0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7;

    // @Dev Topic 0 derived by keccak256("Issue(address,address,address,uint256)")
    uint256 private constant ISSUE_TOPIC = 0x65adeb76912378393e600cb6f64f3310842a42e1eae86273dc775d0c47a0f2dc;

    uint64 private constant GAS_LIMIT = 1000000;

    address private immutable i_origin;

    address private immutable i_destination;

    uint256 private immutable i_originChainId;

    uint256 private immutable i_destinationChainId;

    uint256 public s_counter;

    /// @notice Sets up the reactive contract to monitor and emit callbacks
    /// @param _service Address of the service contract
    /// @param origin Address of the origin chain
    /// @param destination Address of the destination chain
    /// @param originChainId Id of the origin chain
    /// @param destinationChainId Id of the destination chain
    constructor(
        address _service,
        address origin,
        address destination,
        uint256 originChainId,
        uint256 destinationChainId
    ) {
        service = ISystemContract(payable(_service));
        i_origin = origin;
        i_destination = destination;
        i_originChainId = originChainId;
        i_destinationChainId = destinationChainId;

        bytes memory payload = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            i_originChainId,
            i_origin,
            DEPOSIT_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );

        (bool subscriptionSuccess, ) = address(service).call(payload);
        vm = !subscriptionSuccess;

        bytes memory payload2 = abi.encodeWithSignature(
            "subscribe(uint256,address,uint256,uint256,uint256,uint256)",
            i_destinationChainId,
            i_destination,
            ISSUE_TOPIC,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );

        (bool subscriptionSuccess2, ) = address(service).call(payload2);
        vm = !subscriptionSuccess2;
    }

    /// @notice Reacts to the event that meets the subscription criteria
    /// @dev This function is called by the ReactVM only
    /// @dev Decodes the respective event and encode the payload(function to call and input args) to be sent to the destination chain
    /// @dev Emits Callback with necessary destination data. The emitted Callback event will be caught by the reactive network and forwarded to the destination chain with the payload
    /// @param chain_id origin chain ID
    /// @param _contract origin contract address
    /// @param topic_0 Topic 0 of the event
    /// @param topic_1 Topic 1 of the event
    /// @param topic_2 Topic 2 of the event
    /// @param topic_3 Topic 3 of the event
    /// @param data Event data encoded as byte array
    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint256 /* block_number */,
        uint256 /* op_code */
    ) external vmOnly {

        emit Event( 
            chain_id,
            _contract,
            topic_0,
            topic_1,
            topic_2,
            topic_3,
            data,
            s_counter
        );

        if (topic_0 == DEPOSIT_TOPIC) { 
            ( , address user, uint256 amount, ) = abi.decode(data, (address,address,uint256,uint256));

            bytes memory payload = abi.encodeWithSignature(
                "issue(address,address,uint256)", 
                address(0),
                user, 
                amount
            );

            emit Callback(
                i_destinationChainId, 
                i_destination, 
                GAS_LIMIT, 
                payload
            );
        } else { 
            ( , address user, uint256 amount, ) = abi.decode(data, (address, address, uint256 , uint256));

            bytes memory payload = abi.encodeWithSignature(
                "release(address,address,uint256)",
                address(0),
                user,
                amount
            );

            emit Callback(
                i_originChainId, 
                i_origin, 
                GAS_LIMIT, 
                payload
            );
        }
    }

    function pretendVm() external {
        vm = true;
    }

    function subscribe(
        uint256 _chainId,
        address _contract,
        uint256 topic_0
    ) external {
        service.subscribe(
            _chainId,
            _contract,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    function unsubscribe(
        uint256 _chainId,
        address _contract,
        uint256 topic_0
    ) external {
        service.unsubscribe(
            _chainId,
            _contract,
            topic_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    function resetCounter() external {
        s_counter = 0;
    }

    function react(LogRecord calldata log) external override {}
}