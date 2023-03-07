// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Interfaces/IIdentityToken.sol";
import "./Interfaces/IDataManagement.sol";

/** 
 * @title Product NFT creation
 * @dev Contract module which provides product creation mechanism
 * that allow a registered identity to create a product. Also,
 * It allows product owner to link new data with existing product.
 *
 * @dev contract deployer is the default owner.
 * - Owner can call pause/unpause functions
*/
contract ProductNFT is ERC721URIStorage, Ownable, Pausable {

    IIdentityToken private _identityToken;
    IDataManagement private _dataMgt;

    // Mapping from product to creator
    mapping(uint => address) private productToCreator;

    // Mapping from product UID to initial data array length
    mapping(uint => uint) private productToInitialLength;

    // Mapping from data hash to product UID to credit score
    mapping(bytes => mapping(uint => uint)) private dataToProductToCredit;

    // Mapping from Product UID to data hashes
    mapping(uint => bytes[]) private productToData;

    /**
     * @dev Emitted when a new product is created
    */
    event ProductCreated(
        uint creatorID,
        uint productUID,
        string productURI,
        bytes[] datahashes,
        uint[] creditScore
    );

    /**
     * @dev Emitted when a new data hashes are linked with exisitng product NFT
     */
    event NewDataLinked(uint productUID, bytes[] dataHash, uint[] creditScore);

    /**
     * @dev Throws if called by unregistered user.
     */
    modifier ifRegisteredUser() {
        require(
            _identityToken.ifRegistered(_msgSender()) == 1,
            "REJUVE: Not Registered"
        );
        _;
    }

    /**
     * @dev Throws if called by user other than product creator
     */
    modifier onlyProductCreator(uint _productUID) {
        require(
            _msgSender() == productToCreator[_productUID],
            "REJUVE: Only Product Creator"
        );
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        IIdentityToken identityToken_,
        IDataManagement dataMgt_
    ) 
        ERC721(name, symbol) 
    {
        _identityToken = identityToken_;
        _dataMgt = dataMgt_;
    }

    //------------------------------ Step 5: Creating Product - Transaction by Lab / Product Creator ---------------------

    /**
     * @notice A lab can create a product NFT
     * - Caller is the default owner of the product
     * @dev Caller should be a registered identity (having identity token)
     * @param productCreatorId caller identity token ID
     * @param productUID product unique ID = next product UID
     * @param productURI product metadata
     * @param dataHashes list of data hashes used in this product
     * @param creditScores AI assigned credit scores to each data hash
     */
    function createProduct(
        uint productCreatorId,
        uint productUID,
        string memory productURI,
        bytes[] memory dataHashes,
        uint[] memory creditScores
    ) external whenNotPaused ifRegisteredUser {
        require(
            _msgSender() == _identityToken.ownerOf(productCreatorId),
            "REJUVE: Caller is not owner of lab ID"
        ); // if provided incorrect creator ID
        require(
            dataHashes.length == creditScores.length,
            "REJUVE: Not equal length"
        );
        _createProduct(productUID, productURI, dataHashes, creditScores);

        emit ProductCreated(
            productCreatorId,
            productUID,
            productURI,
            dataHashes,
            creditScores
        );
    }

    /**
     * @notice Link new data to existing product NFT
     * @dev only product owner (Lab) can call this function
     */
    function linkNewData(
        uint productUID,
        bytes[] memory newDataHashes,
        uint[] memory creditScores
    ) external whenNotPaused onlyProductCreator(productUID) {
        require(
            newDataHashes.length == creditScores.length,
            "REJUVE: Not equal length"
        );
        require(
            !_linkData(productUID, newDataHashes, creditScores),
            "REJUVE: Data Not Permitted"
        );

        emit NewDataLinked(productUID, newDataHashes, creditScores);
    }

    //-------------------------------------- EXTERNAL VIEWS--------------------------------------------------

    /**
     * @notice returns all data (hashes) used in a specific product
     */
    function getProductToData(
        uint productUID
    ) external view returns (bytes[] memory) {
        return productToData[productUID];
    }

    /**
     * @notice returns credit score assigned to a data hash for a specific product
     */
    function getDataCredit(
        bytes memory dHash,
        uint productUID
    ) external view returns (uint) {
        return dataToProductToCredit[dHash][productUID];
    }

    /**
     * @notice returns owner of given data
     */
    function getDataOwnerAddress(
        bytes memory dHash
    ) external view returns (address) {
        return _identityToken.ownerOf(_dataMgt.getDataOwnerId(dHash));
    }

    /**
     * @notice returns owner of given data
     */
    function getInitialDataLength(
        uint productUID
    ) external view returns (uint) {
        return productToInitialLength[productUID];
    }

    //---------------------------- -------- OWNER FUNCTIONS --------------------------------------------------

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

    //-------------------------------------- Private Functions --------------------------------------------------

    /**
     * @notice Private function to create product NFT
     * - Link permitted data hashes with product UID
     * - Use product UID as NFT token id
     */
    function _createProduct(
        uint productUID,
        string memory productURI,
        bytes[] memory dataHashes,
        uint[] memory creditScores
    ) private {
        require(
            !_linkData(productUID, dataHashes, creditScores),
            "REJUVE: Data Not Permitted"
        );
        _safeMint(_msgSender(), productUID);
        _setTokenURI(productUID, productURI);
        productToCreator[productUID] = _msgSender();
        productToInitialLength[productUID] = dataHashes.length;
    }

    /**
     * @notice Private function to link data hashes with product UID
     * - check if all data hashes are permitted to be used in given product UID
     * - Assign credit scores (by AI) to all data hashes
     * - Link product UID to all data hashes
     */
    function _linkData(
        uint productUID,
        bytes[] memory dataHashes,
        uint[] memory creditScores
    ) private returns (bool) {
        bool notPermitted;
        for (uint i = 0; i < dataHashes.length; i++) {
            if (
                _dataMgt.getPermissionStatus(dataHashes[i], productUID) == 1
            ) {
                // 1 = permitted , 0 = not permitted
                dataToProductToCredit[dataHashes[i]][
                    productUID
                ] = creditScores[i];
                productToData[productUID].push(dataHashes[i]);
            } else {
                notPermitted = true; // if any data hash inside data hash array is not permitted
                break;
            }
        }

        return notPermitted;
    }
}
