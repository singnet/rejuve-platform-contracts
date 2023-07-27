// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
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
contract ProductNFT is ERC721URIStorage, AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    IIdentityToken private _identityToken;
    IDataManagement private _dataMgt;

    // Mapping from product UID to initial data array length
    mapping(uint256 => uint256) private productToInitialLength;

    // Mapping from data hash to product UID to credit score
    mapping(bytes => mapping(uint256 => uint256)) private dataToProductToCredit;

    // Mapping from Product UID to data hashes
    mapping(uint256 => bytes[]) private productToData;

    // Mapping from nonce to its use status
    mapping(uint256 => bool) private usedNonces;

    /**
     * @dev Emitted when a new product is created
    */
    event ProductCreated(
        uint256 productUID,
        address productCreator,
        string productURI,
        bytes[] datahashes,
        uint256[] creditScore
    );

    /**
     * @dev Emitted when new data hashes are linked with exisitng product NFT
    */
    event NewDataLinked(
        uint256 productUID, 
        bytes[] dataHash, 
        uint256[] creditScore
    );

    constructor(
        string memory name,
        string memory symbol,
        address signer,
        IIdentityToken identityToken_,
        IDataManagement dataMgt_
    ) 
        ERC721(name, symbol) 
    {
        _identityToken = identityToken_;
        _dataMgt = dataMgt_;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(SIGNER_ROLE, signer);
    }

    //------------------------- EXTERNAL -----------------------------//

    /**
     * @notice A lab can create a product NFT
     * - Caller is the default owner of the product
     * @dev Caller should be a registered identity (having identity token)
     * @param productUID product unique ID = next product UID
     * @param nonce - A unique number to prevent replay attacks
     * @param signer - Rejuve admin who signed on dataHashes, credit scores & related. 
     * @param signature - Signer's signature
     * @param productURI - Product metadata
     * @param dataHashes - list of data hashes used in this product
     * @param creditScores - AI assigned credit scores to each data hash
     */
    function createProduct(
        uint256 productUID,
        uint256 nonce,
        string memory productURI,
        address signer, 
        bytes memory signature,
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
        _preValidations(
            productUID, 
            nonce, 
            productURI, 
            signer, 
            signature, 
            dataHashes, 
            creditScores
        );  
  
        // require(
        //     dataHashes.length == creditScores.length,
        //     "REJUVE: Not equal length"
        // );
        // require(
        //     signer != address(0), 
        //     "REJUVE: Signer can not be zero"
        // );
        // require(
        //     hasRole(SIGNER_ROLE, signer), // Match signer with SIGNER_ROLE address
        //     "REJUVE: Invalid signer"
        // );
        // require(
        //     _verifyMessage(
        //         productUID, 
        //         nonce, 
        //         productURI, 
        //         signer,
        //         signature,
        //         creditScores,
        //         dataHashes
        //     ),
        //     "REJUVE: Invalid signature of signer"
        // );
        // require(
        //     !_linkData(productUID, dataHashes, creditScores),
        //     "REJUVE: Data Not Permitted"
        // );

        _createProduct(productUID, productURI, dataHashes, creditScores);
    }

    /**
     * @notice Link new data to existing product NFT
     * @dev only product owner (Lab) can call this function
    */
    function linkNewData(
        uint256 productUID,
        uint256 nonce,
        string memory productURI,
        address signer, 
        bytes memory signature,
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
        _preValidations(
            productUID,
            nonce,
            productURI,
            signer,
            signature,
            newDataHashes,
            creditScores
        );

        // require(
        //     newDataHashes.length == creditScores.length,
        //     "REJUVE: Not equal length"
        // );
        // require(
        //     signer != address(0), 
        //     "REJUVE: Signer can not be zero"
        // );
        // require(
        //     hasRole(SIGNER_ROLE, signer), // Match signer with SIGNER_ROLE address
        //     "REJUVE: Invalid signer"
        // );
        // require(
        //     _verifyMessage(
        //         productUID, 
        //         nonce, 
        //         productURI, 
        //         signer,
        //         signature,
        //         creditScores,
        //         newDataHashes
        //     ),
        //     "REJUVE: Invalid signature of signer"
        // );
        // require(
        //     !_linkData(productUID, newDataHashes, creditScores),
        //     "REJUVE: Data Not Permitted"
        // );

        emit NewDataLinked(productUID, newDataHashes, creditScores);
    }

    //------------------- OWNER FUNCTIONS ------------------------------//

    /**
     * @dev Triggers stopped state.
    */
    function pause() external {
        require(
            hasRole(PAUSER_ROLE, _msgSender()), 
            "REJUVE: Must have pauser role to pause"
        );
        _pause();
    }

    /**
     * @dev Returns to normal state.
    */
    function unpause() external {
        require(
            hasRole(PAUSER_ROLE, _msgSender()), 
            "REJUVE: Must have a role to unpause"
        );
        _unpause();
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

    //-------------------------- Public --------------------------//

    /**
     * @dev See {IERC165-supportsInterface}.
    */
    function supportsInterface(
        bytes4 interfaceId
    ) 
        public 
        view 
        override(
            AccessControl, 
            ERC721URIStorage
        ) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    //--------------------- Private Functions ----------------------//

    /**
     * @notice Private function to create product NFT
     * @dev Link permitted data hashes with product UID
     * @dev Use product UID as NFT token id
     */
    function _createProduct(
        uint256 productUID,
        string memory productURI,
        bytes[] memory dataHashes,
        uint256[] memory creditScores
    ) 
        private 
    {
        productToInitialLength[productUID] = dataHashes.length;
        emit ProductCreated(   
            productUID,
            _msgSender(),
            productURI,
            dataHashes,
            creditScores
        );
        _safeMint(_msgSender(), productUID);
        _setTokenURI(productUID, productURI);
    }

    /**
     * @notice Private function to link data hashes with product UID
     * @dev check if all data hashes are permitted to be used in given product UID
     * @dev Assign credit scores (by AI) to all data hashes
     * @dev Link product UID to all data hashes
    */
    function _linkData(
        uint256 productUID,
        bytes[] memory dataHashes,
        uint256[] memory creditScores
    ) 
        private
        returns (bool notPermitted) 
    {
        uint256 dataHashesLength = dataHashes.length;
        for (uint256 i = 0; i < dataHashesLength; i++) {
            if (_dataMgt.getPermissionStatus(dataHashes[i], productUID) == 1) { // 1 = permitted , 0 = not permitted
                dataToProductToCredit[dataHashes[i]][productUID] = creditScores[i]; 
                productToData[productUID].push(dataHashes[i]);
            } else {
                notPermitted = true; // if any dataHash inside dataHashes array is not permitted
                break;
            }
        }
        return notPermitted;
    }
    
    /**
     * @dev Private function to verify signer's signature.
     * @dev First convert dataHashes to bytes32 hash value then 
     * take a hash with other inputs.
     * @return flag true if valid signature.
     */
    function _verifyMessage(
        uint256 productUID,
        uint256 nonce,
        string memory productURI,
        address signer,  
        bytes memory signature,
        uint256[] memory creditScores,
        bytes[] memory dataHashes
    ) 
        private 
        returns (bool flag) 
    {
        require(!usedNonces[nonce], "REJUVE: Signature used already");
        usedNonces[nonce] = true;

        bytes32 data = keccak256(abi.encode(dataHashes));
        bytes32 messagehash = keccak256(
            abi.encodePacked(
                productUID, 
                nonce, 
                productURI, 
                signer, 
                data,
                creditScores, 
                _msgSender(), 
                address(this)
            )
        ); // recreate message

        address signerAddress = messagehash.toEthSignedMessageHash().recover(
            signature
        ); // verify signer using ECDSA

        if (signer == signerAddress) {
            flag = true;
        }
    }

    //------------------------ Helpers -------------------------//

    function _preValidations(
        uint256 productUID,
        uint256 nonce,
        string memory productURI,
        address signer, 
        bytes memory signature,
        bytes[] memory dataHashes,
        uint256[] memory creditScores
    ) 
        private 
    {
        require(
            dataHashes.length == creditScores.length,
            "REJUVE: Not equal length"
        );

        require(
            signer != address(0), 
            "REJUVE: Signer can not be zero"
        );
        require(
            hasRole(SIGNER_ROLE, signer), // Match signer with SIGNER_ROLE address
            "REJUVE: Invalid signer"
        );
        require(
            _verifyMessage(
                productUID, 
                nonce, 
                productURI, 
                signer,
                signature,
                creditScores,
                dataHashes
            ),
            "REJUVE: Invalid signature of signer"
        );
        require(
            !_linkData(productUID, dataHashes, creditScores),
            "REJUVE: Data Not Permitted"
        );
    }
}
