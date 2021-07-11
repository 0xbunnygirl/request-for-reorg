//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.7.6;

contract RequestForReorg {
    struct Request {
        // Address of the miner claiming the reward
        address claimant;
        // The block at which the `reorg` function has to be called
        uint48 executeBlock;
        // The expiry of the request
        // If no reorgs are made, the requester can withdraw their reward
        uint48 expiryBlock;
        // Amount of reward in Ether attached to the reorg request
        uint128 reward;
    }
    /// @notice Maps the requester to a Request object. A single address can only make a single request.
    mapping(address => Request) public requests;

    event Requested(address indexed requester, uint48 executeBlock, uint48 expiryBlock, uint128 reward);
    event Reorged(address indexed requester, address indexed reorger);
    event RewardClaimed(address indexed requester);
    event Slashed(address indexed requester);
    event Withdrawn(address indexed requester);

    /// @notice Creates a request to reorg the blockchain
    /// @param executeBlock is the block at which the reorg function has to be called
    /// @param expiryBlock is the block at which the request expires
    function request(uint48 executeBlock, uint48 expiryBlock) external payable {
        require(requests[msg.sender].expiryBlock == 0, "Existing request");
        require(expiryBlock > executeBlock, "expiryBlock must be after executeBlock");

        // Overflow checks
        require(msg.value < type(uint128).max, "Overflow value");

        requests[msg.sender] = Request({
            claimant: address(0), // begin as unclaimed
            executeBlock: executeBlock,
            expiryBlock: expiryBlock,
            reward: uint128(msg.value)
        });

        emit Requested(msg.sender, executeBlock, expiryBlock, uint128(msg.value));
    }

    /// @notice Reorg that apportions the reward to a miner but does not transfer it until expiry
    ///         Invariant: reorg can only be called from a block number that has past.
    /// @param requester is the address at which the Request object is attached to
    function reorg(address requester) external {
        require(requests[requester].expiryBlock != 0, "Request does not exist");
        require(block.coinbase == msg.sender, "Must be miner");
        require(uint48(block.number) == requests[requester].executeBlock, "Must be executed at executeBlock");

        // Updating the claim information
        requests[requester].claimant = msg.sender;

        emit Reorged(requester, msg.sender);
    }

    /// @notice Claiming the reward at the end of expiry
    /// @param requester is the address at which the Request object is attached to
    function claimReward(address requester)  external {
        require(requests[requester].expiryBlock > block.timestamp, "Must be after expiryBlock");
        require(requests[requester].claimant == msg.sender, "Must match claimant");

        uint reward = requests[requester].reward;
        delete requests[requester];

        (bool success,) = (msg.sender).call{value: reward}("");
        require(success, "Low level transfer error");

        emit RewardClaimed(requester);
    }

    /// @notice Forfeits the reward for the miner due to some violation of trust. Reward remains stuck on the contract.
    function slash() external {
        require(requests[msg.sender].expiryBlock != 0, "Request does not exist");
        require(block.timestamp < requests[msg.sender].expiryBlock, "Must be before expiryBlock");
        require(requests[msg.sender].claimant != address(0), "Must be claimed");

        delete requests[msg.sender];

        emit Slashed(msg.sender);
    }

    /// @notice Withdraws the reward amount if no miners claim the reward by reorg-ing
    function withdraw() external {
        require(requests[msg.sender].expiryBlock != 0, "Request does not exist");
        require(uint48(block.number) > requests[msg.sender].expiryBlock, "Must be after expiryBlock");
        require(requests[msg.sender].claimant == address(0), "Reward claimed");

        uint reward = uint(requests[msg.sender].reward);
        delete requests[msg.sender];

        // Withdrawing the original reward amount
        (bool success,) = (msg.sender).call{value: reward}("");
        require(success, "Low level transfer error");

        emit Withdrawn(msg.sender);
    }
}