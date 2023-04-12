// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;
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
    mapping(uint => uint) private productEarning; 

    // Mapping from productUID to totalWithdrawal
    mapping(uint => uint) private withdrawalBalance; 
   
   // Mapping from holder to productUID to lastPoint
    mapping(address => mapping(uint => uint)) private holderLastPoint;

    /**
     * @dev Emitted when a new purchase is made
    */
    event PaymentReceived(address sender, uint productUID, uint amount);

    /**
     * @dev Emitted when a holder withdraws an amount
    */
    event Withdrawal(address holder, uint productUID, uint amount);

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
        uint productUID, 
        uint amount
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
        uint productUID, 
        uint contributionPoints
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
    function getProductEarning(uint productUID) external view returns (uint) {
        return productEarning[productUID];
    }

    /**
     * @return Total withdrawal amount of a product
    */
    function getTotalWithdrawal(uint productUID) external view returns (uint) {
        return withdrawalBalance[productUID];
    }

    /**
     * @return Shard holder last point => Last total earning of a product
    */
    function getHolderLastPoint(
        address holder,
        uint productUID
    ) external view returns (uint) {
        return holderLastPoint[holder][productUID];
    }

    //------------------------------ PUBLIC --------------------------------//

    /**
     * @return Total Shard balance(Traded & locked) of a caller
    */
    function _getShardBalance(uint productUID) public view returns (uint) {
        uint[] memory productIds = _productShards.getProductIDs(productUID);
        uint lockedBalance = _productShards.balanceOf(
            _msgSender(),
            productIds[0]
        );
        uint tradedBalance = _productShards.balanceOf(
            _msgSender(),
            productIds[1]
        );
        uint balance = lockedBalance + tradedBalance;
        return balance;
    }

    //------------------------------ PRIVATE --------------------------------//

    function _deposit(uint productUID, uint amount) private {   
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
    function _withdraw(uint productUID, uint contributionPoints) private {
        uint totalEarningForCaller = productEarning[productUID] -
            holderLastPoint[_msgSender()][productUID];
        uint amount = (contributionPoints * totalEarningForCaller) / 10000; // calculate RJV
        require(amount > 0, "REJUVE: No user earning");

        holderLastPoint[_msgSender()][productUID] = productEarning[
            productUID
        ]; 
        withdrawalBalance[productUID] += amount;

        emit Withdrawal(_msgSender(), productUID, amount);
        _rejuveToken.transfer(_msgSender(), amount);
    }
}
