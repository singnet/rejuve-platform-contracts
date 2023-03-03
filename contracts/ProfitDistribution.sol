// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./Interfaces/IProductShards.sol";
import "hardhat/console.sol";

contract ProfitDistribution is Context {
    IERC20 private _rejuveToken;
    IProductShards private _productShards;

    mapping(uint => uint) productEarning; // Total earned amount
    mapping(uint => uint) withdrawalBalance; // Total withdrawal amount of a product balance
    mapping(address => mapping(uint => uint)) holderLastPoint;

    event PaymentReceived(address sender, uint productUID, uint amount);
    event Withdrawal(address holder, uint productUID, uint amount);

    //------------------------------ Constructor --------------------------------//

    constructor(address rejuveToken_, address productShards_) {
        _rejuveToken = IERC20(rejuveToken_);
        _productShards = IProductShards(productShards_);
    }

    //------------------------------ EXTERNAL --------------------------------//

    function deposit(uint _productUID, uint _amount) external {
        require(_amount > 0, "REJUVE: Zero amount");
        _rejuveToken.transferFrom(_msgSender(), address(this), _amount);
        productEarning[_productUID] += _amount;

        emit PaymentReceived(_msgSender(), _productUID, _amount);
    }

    function withdraw(uint _productUID, uint contributionPoints) external {
        // claim and withdraw are same
        require(contributionPoints > 0, "REJUVE: Zero contribution");
        require(productEarning[_productUID] > 0, "REJUVE: No product earning");
        require(_getShardBalance(_productUID) > 0, "REJUVE: No shard balance");

        _withdraw(_productUID, contributionPoints);
    }

    //----------------- VIEWS ------------

    function getProductEarning(uint productUID) external view returns (uint) {
        return productEarning[productUID];
    }

    function getTotalWithdrawal(uint _productUID) external view returns (uint) {
        return withdrawalBalance[_productUID];
    }

    function getHolderLastPoint(
        address _holder,
        uint _productUID
    ) external view returns (uint) {
        return holderLastPoint[_holder][_productUID];
    }

    //------------------------------ PRIVATE --------------------------------//

    function _getShardBalance(uint _productUID) public view returns (uint) {
        uint[] memory productIds = _productShards.getProductIDs(_productUID);
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

    // percentage contribution in basis points => calculate off-chain
    // 18% is equal to 1800 bps

    function _withdraw(uint _productUID, uint contributionPoints) private {
        uint userEarning = productEarning[_productUID] -
            holderLastPoint[_msgSender()][_productUID];
        uint amount = (contributionPoints * userEarning) / 10000; // calculate RJV
        require(amount > 0, "REJUVE: No user earning");

        holderLastPoint[_msgSender()][_productUID] = productEarning[
            _productUID
        ]; // update caller's last point
        withdrawalBalance[_productUID] += amount;

        _rejuveToken.transfer(_msgSender(), amount);

        emit Withdrawal(_msgSender(), _productUID, amount);
    }
}
