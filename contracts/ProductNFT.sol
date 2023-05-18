// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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

    // Mapping from product UID to initial data array length
    mapping(uint256 => uint256) private productToInitialLength;

    // Mapping from data hash to product UID to credit score
    mapping(bytes => mapping(uint256 => uint256)) private dataToProductToCredit;

    // Mapping from Product UID to data hashes
    mapping(uint256 => bytes[]) private productToData;

    /**
     * @dev Emitted when a new product is created
    */
    event ProductCreated(
        uint256 creatorID,
        uint256 productUID,
        string productURI,
        bytes[] datahashes,
        uint256[] creditScore
    );

    /**
     * @dev Emitted when a new data hashes are linked with exisitng product NFT
     */
    event NewDataLinked(uint256 productUID, bytes[] dataHash, uint256[] creditScore);

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

    //--------- Step 5: Creating Product - Transaction by Lab / Product Creator ---//

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
        uint256 productCreatorId,
        uint256 productUID,
        string memory productURI,
        bytes[] memory dataHashes,
        uint256[] memory creditScores
    ) 
        external 
        whenNotPaused 
    {
        require(
            _identityToken.ifRegistered(_msgSender()) == 1,
            "REJUVE: Not Registered"
        );
        require(
            _msgSender() == _identityToken.ownerOf(productCreatorId),
            "REJUVE: Caller is not owner of lab ID"
        ); // if provided incorrect creator ID
        require(
            dataHashes.length == creditScores.length,
            "REJUVE: Not equal length"
        );
        require(
            !_linkData(productUID, dataHashes, creditScores),
            "REJUVE: Data Not Permitted"
        );

        _createProduct(productUID, productCreatorId, productURI, dataHashes, creditScores);
    }

    /**
     * @notice Link new data to existing product NFT
     * @dev only product owner (Lab) can call this function
    */
    function linkNewData(
        uint256 productUID,
        bytes[] memory newDataHashes,
        uint256[] memory creditScores
    ) 
        external 
        whenNotPaused 
    {
        require(
            _msgSender() == ownerOf(productUID),
            "REJUVE: Only Product Creator"
        );
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

    //-------------------- EXTERNAL VIEWS-----------------------------//

    /**
     * @notice returns all data (hashes) used in a specific product
    */
    function getProductToData(
        uint256 productUID
    ) external view returns (bytes[] memory) {
        return productToData[productUID];
    }

    /**
     * @notice returns credit score assigned to a data hash for a specific product
    */
    function getDataCredit(
        bytes memory dHash,
        uint256 productUID
    ) external view returns (uint256) {
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
     * @notice returns initial data length 
     * Initial data => All data hashes that are submitted before product NFT creation
    */
    function getInitialDataLength(
        uint256 productUID
    ) external view returns (uint256) {
        return productToInitialLength[productUID];
    }

    //------------------- OWNER FUNCTIONS ------------------------------//

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

    //--------------------- Private Functions --------------------------//

    /**
     * @notice Private function to create product NFT
     * - Link permitted data hashes with product UID
     * - Use product UID as NFT token id
     */
    function _createProduct(
        uint256 productUID,
        uint256 productCreatorId,
        string memory productURI,
        bytes[] memory dataHashes,
        uint256[] memory creditScores
    ) 
        private 
    {
        productToInitialLength[productUID] = dataHashes.length;
        emit ProductCreated(
            productCreatorId,
            productUID,
            productURI,
            dataHashes,
            creditScores
        );
        _safeMint(_msgSender(), productUID);
        _setTokenURI(productUID, productURI);
    }

    /**
     * @notice Private function to link data hashes with product UID
     * - check if all data hashes are permitted to be used in given product UID
     * - Assign credit scores (by AI) to all data hashes
     * - Link product UID to all data hashes
     */
    function _linkData(
        uint256 productUID,
        bytes[] memory dataHashes,
        uint256[] memory creditScores
    ) 
        private
        returns (bool) 
    {
        bool notPermitted;
        for (uint256 i = 0; i < dataHashes.length; i++) {
            if (_dataMgt.getPermissionStatus(dataHashes[i], productUID) == 1) { // 1 = permitted , 0 = not permitted
                dataToProductToCredit[dataHashes[i]][productUID] = creditScores[i]; 
                productToData[productUID].push(dataHashes[i]);
            } else {
                notPermitted = true; // if any data hash inside data hash array is not permitted
                break;
            }
        }
        return notPermitted;
    }
}
