// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IProductNFT.sol";

/** @dev Contract module which administrative mechanism
 * that allows to set Administrator roles & Product NFT
 * address and ID.
 * Also, it allows an admin to pause and unpause
 * mint function.
*/

contract ShardAdministration is Context, AccessControl, Pausable {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Product NFT contract address
    IProductNFT productNFT; 

    // Rejuve admin
    address _rejuveAdmin;

    // Product NFT token ID
    uint productNftID;  

    constructor (
        address rejuveAdmin_,
        IProductNFT productNFT_,
        uint productNftID_
    ){    
        _setupRole(DEFAULT_ADMIN_ROLE, rejuveAdmin_);
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, rejuveAdmin_);
        _rejuveAdmin = rejuveAdmin_;
        productNFT = productNFT_;
        productNftID = productNftID_;
    }

//---------------------------------------  EXTERNAL --------------------------------------------------

    /**
     * @dev Triggers stopped state.
     *
    */
    function pause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "REJUVE: Must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Returns to normal state.
    */
    function unpause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "REJUVE: Must have role to unpause");
        _unpause();
    }
}