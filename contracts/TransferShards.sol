// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
import "./FutureShards.sol";

/** @notice Contract module that provides shards transfer mechanism for 
 * both "Traded" and "Locked" types.
 *
 * @dev System should lock transfer of 50% of tokens for a specific time.
 * After this locking period, owner of shards can sale them as traded tokens
 * 
 * @dev contract deployer is the default owner. 
 * - Only Owner can call pause/unpause functions
*/

contract TransferShards is FutureShards {

    constructor(string memory uri_, address productNFT_) 
        FutureShards(uri_, productNFT_) 
    {}

//----------------------------------------

    /**
     * @dev Triggers stopped state.
     *
    */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

//---------------------------------------- PUBLIC ----------------------------------------------//
    /**
     * @dev Overrides {ERC1155 safeTransferFrom}
     * Steps:
     * 1. Check ID type
     * 2 If it is "locked" then check block.timestamp, 
     *  - if it is more than locking period, allow transfer
     *  - if less, lock transfer
     *  
     * 3.Else (Means Type ID is "traded"), allow transfer 
    */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        public 
        override 
    {
        if (keccak256(bytes(typeToState[id])) == keccak256(bytes("LOCKED"))){ // check type if it is LOCKED  
            require(block.timestamp > productToLockPeriod[typeToProduct[id]], "REJUVE: Cannot sale 50% of shards before locking period"); 
            _transferShard(from, to, id, amount, data);
            
        } else { // if type is TRADED
            _transferShard(from, to, id, amount, data);
        } 
    }

//---------------------------------------- PRIVATE----------------------------------------------//

    /**
     * @dev See {ERC1155-safeTransferFrom}.
    */
    function _transferShard(    
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        private 
        whenNotPaused 
    {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);        
    }
}
