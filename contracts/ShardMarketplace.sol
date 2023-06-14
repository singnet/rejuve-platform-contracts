// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./Interfaces/IRejuveToken.sol";
import "./Interfaces/IProductShards.sol";

/** 
 * @title Product Shards Marketplace 
 * @dev Contract module which provides a shards trading platform
 * that allows a shard holder to place their shards for others 
 * to purchase them.
*/
contract ShardMarketplace is Context, Ownable, Pausable {

    using ECDSA for bytes32;

    enum ListingStatus {
        NotListed,
        Listed
    }

    IProductShards private _productShard;
    IRejuveToken private _rejuveToken;

    // Mappingn from holder to productUID to listing status
    mapping(address => mapping(uint256 => ListingStatus)) private listingStatus;

    // Mapping from holder to productUID to per shard price
    mapping (address => mapping (uint256 => uint256)) private holderShardPrice;

    // Mapping from nonce to use status
    mapping(uint256 => bool) private usedNonces;

    /**
     * @dev Emitted when a new list is created by a shard holder
    */
    event Listed(address holder, uint256 productUID, uint256 amount, uint256 price);

    /**
     * @dev Emitted when a holder cancels a list 
    */
    event CancelList(address holder, uint256 productUID);

    /**
     * @dev Emitted when a holder updates a list 
    */
    event ListUpdated(address holder, uint256 productUID, uint256 newPrice);

    /**
     * @dev Emitted when a buyer purchases shards
    */
    event Sold(address seller, address buyer, uint256 productUID, uint256 shardAmount, uint256 unitPrice);

    /**
     * @dev Throws if caller has not approved marketplace to execute shards transfer
    */
    modifier isApproved() {
        require(_productShard.isApprovedForAll(_msgSender(), address(this)), "REJUVE: Not approved");
        _;
    }

    /**
     * @dev Throws if shards are not listed by a holder
    */
    modifier isListed(uint productUID, address caller) {
        require(listingStatus[caller][productUID] == ListingStatus.Listed, "REJUVE: Not listed");
        _;
    }

    constructor(IProductShards productShard_, IRejuveToken rejuveToken_) {
        _productShard = productShard_;
        _rejuveToken = rejuveToken_;
    }

    //------------------------- EXTERNAL --------------------------------//

    /**
     * @notice Allow shards holder to list their shards on marketplace
     * @dev Check approval and contract pause status before execution
     * @param productUID ProductUID of Shards which holder is selling
     * @param shardPrice Per unit price of a shard
     * @param id Type ID (0 for Locked type, 1 for Traded)
    */
    function listShard(
        uint256 productUID, 
        uint256 shardPrice, 
        uint256 id
    ) 
        external 
        isApproved 
        whenNotPaused
    {
        require(listingStatus[_msgSender()][productUID] == ListingStatus.NotListed, "REJUVE: Listed already");
        require(shardPrice > 0, "Rejuve: Price cannot be zero");
        uint256 amount = _productShard.balanceOf(_msgSender(), id);
        require(amount > 0, "REJUVE: Insufficent balance");
        _listShard(productUID, shardPrice, amount);
    }

    /**
     * @notice Allow holder to update shard price
     * @param productUID UID of product 
     * @param newPrice New price of per shard unit
    */
    function updateList(
        uint256 productUID, 
        uint256 newPrice
    ) 
        external 
        isListed(productUID, _msgSender())
        whenNotPaused
    {
        require(newPrice > 0, "REJUVE: Price cannot be zero");
        _updateList(productUID, newPrice);
    }
    /**
     * @notice Allow holder to cancel a list
     * @dev Check if shards are listed already
    */
    function cancelList(uint256 productUID) 
        external 
        isListed(productUID, _msgSender()) 
        whenNotPaused 
    {
        _cancelList(productUID);
    }

    /**
     * @notice Allow a buyer to purchase shards
     * @dev If buyer has a disocunt coupon, check coupon's validity by 
     * checking admin's signature.
     * @dev If buyer has no discount coupon, pass "0" in Nonce, Coupon and empty signature 
     * @dev Apply discount only if a buyer has a valid coupon 
     * @param shardAmount - How many shards buyer is purchasing
     * @param id - Type ID(0 for Locked, 1 for Traded)
     * @param coupon - Discount coupons in BPS e.g. 1% = 100 bps
     * @param nonce - A unique to prevent reply attacks
     * @param seller - Seller's address
     * @param signature - Admin's signature to check if buyer has valid discount coupons
    */
    function buy(
        uint256 productUID, 
        uint256 shardAmount, 
        uint256 id, 
        uint256 coupon,
        uint256 nonce,
        address seller,
        bytes memory signature
    ) 
        external 
        isListed(productUID, seller) 
        whenNotPaused
    {
        require(shardAmount > 0, "REJUVE: Shard amount cannot be zero");
        require(
            shardAmount <= _productShard.balanceOf(seller, id), 
            "REJUVE: Insufficient shard amount"
        );
        _buy(productUID, shardAmount, id, coupon, nonce, seller, signature);
    }


    //---------------------------- OWNER FUNCTIONS --------------------------------//

    /**
     * @dev Triggers stopped state.
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

    //---------------------- VIEWS ----------------------------//

    /**
     * @return listing status of a holder
    */
    function getLisitingStatus(address holder, uint256 productUID) external view returns(ListingStatus) {
        return listingStatus[holder][productUID];
    }

    /**
     * @return Per shard price of a holder
     * @param holder - Shard holder address
     * @param productUID - Product unique ID
    */
    function getShardPrice(address holder, uint256 productUID) public view returns (uint256) {
        return holderShardPrice[holder][productUID];
    }
    
    //------------------------ PRIVATE --------------------------//

    /**
     * @dev Change listing status of caller
     * @dev Add shard price of a holder
    */
    function _listShard(uint256 productUID, uint256 price, uint256 amount) private {
        listingStatus[_msgSender()][productUID] = ListingStatus.Listed;
        holderShardPrice[_msgSender()][productUID] = price;
        emit Listed(_msgSender(), productUID, amount, price);
    }

    /**
     * @dev Update shard price of a holder
    */
    function _updateList(uint256 productUID, uint256 newPrice) private {
        holderShardPrice[_msgSender()][productUID] = newPrice;
        emit ListUpdated(_msgSender(), productUID, newPrice);
    }

    /**
     * @dev Update listing status
     * @dev Update Price of shards to zero for caller
    */
    function _cancelList(uint256 productUID) private {
        listingStatus[_msgSender()][productUID] = ListingStatus.NotListed;
        holderShardPrice[_msgSender()][productUID] = 0;
        emit CancelList(_msgSender(), productUID);
    }

    /**
     * @dev Check if caller (buyer) has valid coupon by checking admin's signature
     * @dev Return true if we get a valid Admin address 
    */
    function _verifyMessage(
        bytes memory signature,
        uint256 coupon,
        uint256 nonce
    ) private returns (bool) {
        require(!usedNonces[nonce], "REJUVE: Signature used already");
        usedNonces[nonce] = true;
        bytes32 messagehash = keccak256(
            abi.encodePacked(owner(), _msgSender(), address(this), coupon, nonce)
        ); // recreate message
        address signerAddress = messagehash.toEthSignedMessageHash().recover(
            signature
        ); // verify signer using ECDSA

        if (owner() == signerAddress) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Check signature validity If coupon, signature and nonce are not empty
     * @dev If no coupon available OR invalid signature, execute transfer method directly
    */
    function _buy(
        uint256 productUID, 
        uint256 shardAmount, 
        uint256 id, 
        uint256 coupon,
        uint256 nonce,
        address seller,
        bytes memory signature
    ) 
        private 
    {
        uint256 unitPrice = getShardPrice(seller, productUID);
        uint256 totalPrice = shardAmount * unitPrice; // price in rjv

        if(isNotEmpty(signature, coupon, nonce)) {
            bool discountApplied = _verifyMessage(signature, coupon, nonce);
            if(discountApplied) {
                uint256 discount = coupon * totalPrice / 10000;
                totalPrice = totalPrice - discount;
                _transferAmount(seller, productUID, unitPrice, totalPrice, id, shardAmount);
            } else {
                _transferAmount(seller, productUID, unitPrice, totalPrice, id, shardAmount);
            }
        } else {
            _transferAmount(seller, productUID, unitPrice, totalPrice, id, shardAmount);
        }
    }

    /**
     * @dev Check if buyer has sufficient RJV balance
     * @dev Check if Buyer has approved marketplace to transfer RJVs
     * @dev Send RJV to shards seller 
     * @dev Send Shards ownership to buyer
    */
    function _transferAmount(
        address seller, 
        uint256 productUID, 
        uint256 unitPrice, 
        uint256 totalPrice, 
        uint256 id, 
        uint256 shardAmount
    ) private {    
        require(_rejuveToken.balanceOf(_msgSender()) >= totalPrice, "REJUVE Insuffient RJV balance");
        require(_rejuveToken.allowance(_msgSender(), address(this)) >= totalPrice, "REJUVE: Not approved");
        
        emit Sold(seller, _msgSender(), productUID, shardAmount, unitPrice);
        
        // Sending RJV tokens
        _rejuveToken.transferFrom(_msgSender(), seller, totalPrice);

        // Transfer shards ownership
        _productShard.safeTransferFrom(seller, _msgSender(), id, shardAmount, "");
    }

    /**
     * @dev Check non empty values 
    */
    function isNotEmpty(bytes memory signature, uint256 coupon, uint256 nonce) private pure returns(bool) {
        if(coupon != 0 && signature.length != 0 && nonce !=0){
            return true;
        } else {
            return false;
        }
    }
}