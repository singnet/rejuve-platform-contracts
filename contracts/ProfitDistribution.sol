// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IProductShards.sol";

/** 
 * @title Profit distribution from final product
 * @dev Contract module which provides a profit distribution mechanism
 * that allows anyone to deposit an amount of RJV tokens to the contract that 
 * can be claimed by shard holders as per their shard holdings
 * 
 * Also, Only owner can pause/unpause the contract
*/
contract ProfitDistribution is Context, Ownable, Pausable {

    IERC20 private _rejuveToken;
    IProductShards private _productShards;

    // Mapping from productUID to Earned amount 
    mapping(uint256 => uint256) private productEarning; 

    // Mapping from productUID to totalWithdrawal
    mapping(uint256 => uint256) private withdrawalBalance; 
   
   // Mapping from holder to productUID to lastPoint
    mapping(address => mapping(uint256 => uint256)) private holderLastPoint;

    /**
     * @dev Emitted when a new purchase is made
    */
    event PaymentReceived(address sender, uint256 productUID, uint256 amount);

    /**
     * @dev Emitted when a holder withdraws an amount
    */
    event Withdrawal(address holder, uint256 productUID, uint256 amount);

    //------------------------------ Constructor --------------------------------//

    constructor(address rejuveToken_, address productShards_) {
        _rejuveToken = IERC20(rejuveToken_);
        _productShards = IProductShards(productShards_);
    }

    //------------------------------ EXTERNAL --------------------------------//

    /**
     * @notice Anyone can deposit RJV tokens e.g. individual buyer, Rejuve or distributors
     * @dev Contract can accept & store RJV tokens 
     * @param productUID token Id of a product that is being purchased
     * @param amount deposited RJV tokens / price (in RJV) of the item
    */
    function deposit(
        uint256 productUID, 
        uint256 amount
    ) 
        external 
        whenNotPaused 
    {
        require(amount > 0, "REJUVE: Zero amount");
        _deposit(productUID, amount);
    }

    /**
     * @notice A shard holder can withdraw/claim his earning after a product is purchased by 
     * a buyer (Indivuduals or Distributors)
     * @param productUID - Id of a product from which holder is withdrawing his earning
     * @param contributionPoints - caller contribution in overall product 
     * (calculate off-chain)
    */
    function withdraw(
        uint256 productUID, 
        uint256 contributionPoints
    ) 
        external 
        whenNotPaused 
    {
        require(contributionPoints > 0, "REJUVE: Zero contribution");
        require(productEarning[productUID] > 0, "REJUVE: No product earning");
        require(_getShardBalance(productUID) > 0, "REJUVE: No shard balance");

        _withdraw(productUID, contributionPoints);
    }

    //---------------------------- OWNER FUNCTIONS --------------//

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

    //----------------------------- VIEWS ----------------------//

    /**
     * @return Total earning of a product
    */
    function getProductEarning(uint256 productUID) external view returns (uint256) {
        return productEarning[productUID];
    }

    /**
     * @return Total withdrawal amount of a product
    */
    function getTotalWithdrawal(uint256 productUID) external view returns (uint256) {
        return withdrawalBalance[productUID];
    }

    /**
     * @return Shard holder last point => Last total earning of a product
    */
    function getHolderLastPoint(
        address holder,
        uint256 productUID
    ) external view returns (uint256) {
        return holderLastPoint[holder][productUID];
    }

    //------------------------------ PUBLIC --------------------------------//

    /**
     * @return Total Shard balance(Tradable & locked) of a caller
    */
    function _getShardBalance(uint256 productUID) public view returns (uint256) {
        uint256[] memory productIds = _productShards.getProductIDs(productUID);
        uint256 lockedBalance = _productShards.balanceOf(
            _msgSender(),
            productIds[0]
        );
        uint256 tradedBalance = _productShards.balanceOf(
            _msgSender(),
            productIds[1]
        );
        uint256 balance = lockedBalance + tradedBalance;
        return balance;
    }

    //------------------------------ PRIVATE --------------------------------//

    function _deposit(uint256 productUID, uint256 amount) private {   
        productEarning[productUID] += amount;
        emit PaymentReceived(_msgSender(), productUID, amount);   
        _rejuveToken.transferFrom(_msgSender(), address(this), amount);  
    }

    /**
     * @dev Contribution points are basis points (1% = 100 bps => calculate off-chain)
     * @param contributionPoints - Basis points of the caller (calculate off-chain)
     * 1. Get total product earning for caller
     * 2. Calculate earned RJV tokens  
     * 3. Update caller last points => Assign "current product earning" to holder last point
     * 4. Update product withdrawal balance 
     * 5. Transfer RJV tokens from contract to caller
     */
    function _withdraw(uint256 productUID, uint256 contributionPoints) private {
        uint256 totalEarningForCaller = productEarning[productUID] -
            holderLastPoint[_msgSender()][productUID];
        uint256 amount = (contributionPoints * totalEarningForCaller) / 10000; // calculate RJV
        require(amount > 0, "REJUVE: No user earning");

        holderLastPoint[_msgSender()][productUID] = productEarning[
            productUID
        ]; 
        withdrawalBalance[productUID] += amount;

        emit Withdrawal(_msgSender(), productUID, amount);
        _rejuveToken.transfer(_msgSender(), amount);
    }
}
