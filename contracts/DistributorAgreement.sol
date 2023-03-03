// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/** @dev Contract module which provides a distributor agreement mechanism
 * that allows a distributor OR anyone with valid distributor's signature
 * to create a business agreement.
*/
contract DistributorAgreement is Ownable, Pausable {
    using ECDSA for bytes32;

    struct Distributor {
        bytes agreement;
        uint productUID;
        uint units;
        uint unitPrice;
        uint percentage;
    }

    // Mapping from distributor to info
    mapping(address => Distributor) private distributors;

    // Mapping from nonce to status
    mapping(uint => bool) private usedNonce;

    /**
     * @dev Emitted when a new agreement is created
    */
    event DistributorCreated(
        address distributor,
        bytes agreement,
        uint productUID,
        uint units,
        uint unitPrice,
        uint percentage
    );

    /**
     * @dev Distributor or anyone with a valid signature can create an agreement
     * @param _distributor address 
     * @param _sign distributor signature
     * @param _agreement hash
     * @param _productUID product unique ID on which agreement is made
     * @param _totalUnits purchased 
     * @param _unitPrice of an item
     * @param _percentage agreed percentage, distributor will pay to Rejuve
     * @param _nonce a unique number to prevent replay attacks
    */
    function createAgreement(
        address _distributor,
        bytes memory _sign,
        bytes memory _agreement,
        uint _productUID,
        uint _totalUnits,
        uint _unitPrice,
        uint _percentage,
        uint _nonce
    ) external {
        require(_distributor != address(0), "REJUVE: Zero address");
        require(_totalUnits > 0, "REJUVE: Total units can not be zero");
        require(_unitPrice > 0, "REJUVE: Price can not be zero");
        require(_percentage > 0, "REJUVE: Percentage can not be zero");
        require(
            verifySignature(_distributor, _sign, _agreement, _nonce),
            "REJUVE: Invalid signature"
        );

        _createAgreement(
            _distributor,
            _agreement,
            _productUID,
            _totalUnits,
            _unitPrice,
            _percentage
        );
    }

    //---------------------------- OWNER FUNCTIONS --------------//

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

    //-------------------- EXTERNAL VIEWS --------------------//

    /**
     * @return Distributor's agreement information
    */
    function getDistributorData(
        address _distributor
    ) external view returns (Distributor memory) {
        return distributors[_distributor];
    }

    //-------------------- PRIVATE --------------------------//

    function _createAgreement(
        address _distributor,
        bytes memory _agreement,
        uint _productUID,
        uint _totalUnits,
        uint _unitPrice,
        uint _percentage
    ) private {
        Distributor storage dist = distributors[_distributor];
        dist.agreement = _agreement;
        dist.productUID = _productUID;
        dist.units = _totalUnits;
        dist.unitPrice = _unitPrice;
        dist.percentage = _percentage;

        emit DistributorCreated(
            _distributor,
            _agreement,
            _productUID,
            _totalUnits,
            _unitPrice,
            _percentage
        );
    }

    /**
     * @dev Private function to verify user signature
     * @return bool flag true if valid signature
    */
    function verifySignature(
        address _distributor,
        bytes memory _sign,
        bytes memory _agreement,
        uint _nonce
    ) private returns (bool) {
        require(!usedNonce[_nonce], "REJUVE: Nonce used already");
        usedNonce[_nonce] = true;
        bytes32 msgHash = keccak256(
            abi.encodePacked(_distributor, _agreement, _nonce, address(this))
        );
        address signer = msgHash.toEthSignedMessageHash().recover(_sign);

        if (signer == _distributor) {
            return true;
        } else {
            return false;
        }
    }
}
