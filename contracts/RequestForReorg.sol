//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

contract RequestForReorg {
    event Request(
         uint64 executeBlock,
        uint64 expiryBlock,
        uint128 value,
        address indexed requester);

    event Reorg(uint64 indexed executeBlock,
        address indexed miner,
        uint128 value);

    struct Request {
        uint64 executeBlock;
        uint64 expiryBlock;
        uint128 value;
    }
    mapping(address => Request) public requests;

    function request(uint executeBlock, uint expiryBlock) payable {
        require(requests[msg.sender].expiryBlock == 0, "Existing request");
        require(block.number > executeBlock, "executeBlock must be in the past");
        require(block.number < expiryBlock, "expiryBlock must be in the future");

        // Overflow checks
        require(executeBlock < type(uint64).max, "Overflow executeBlock");
        require(expiryBlock < type(uint64).max, "Overflow expiryBlock");
        require(value < type(uint128).max, "Overflow value");

        requests[msg.sender] = Request({
            executeBlock: uint64(executeBlock),
            expiryBlock: uint64(expiryBlock),
            value: uint128(msg.value)
        });
    }

    function reorg(address requester) {
        require(requests[msg.sender].expiryBlock != 0, "Request does not exist");
        require(block.coinbase == msg.sender, "Must be miner");
        require(block.number == requests[requester.executeBlock], "Must be executed at executeBlock");
        (msg.sender).call{value: requests[requester].value}("");
    }

    function withdraw() {
        require(requests[msg.sender].expiryBlock != 0, "Request does not exist");
        require(block.number > requests[requests[msg.sender].expiryBlock], "Must be after expiryBlock");
        (msg.sender).call{value: requests[msg.sender].value}("");
    }
}