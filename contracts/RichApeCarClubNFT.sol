// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RichApeCarClubNFT is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using SafeMath for uint256;
    using SafeMath for uint8;

    uint256 public constant preSalePrice = 0.012 ether;
    uint256 public constant publicSalePrice = 0.015 ether;
    uint256 public constant supplyForPreSale = 4000;
    uint256 public mintLimit = 100;
    uint256 public mintLimitForPreSale = 4;
    uint256 public giveawaySupply = 777;
    uint256 public maxPerAddressDuringMint;
    uint256 public maxSupply = 7777;

    bool public saleStarted = false;
    bool public presaleStarted = false;
    bool public revealed = false;

    string private baseExtension = ".json";
    string private baseURI;
    string private notRevealedURI;

    bytes32 private _merkleRoot;

    constructor(uint256 maxBatchSize_, string memory baseURI_)
        ERC721A("RichApeCarClub", "RACC")
    {
        maxPerAddressDuringMint = maxBatchSize_;
        baseURI = baseURI_;
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Mint NFTs for giveway
     */
    function mintForGiveaway() external onlyOwner {
        require(totalSupply() == 0, "Mint already started");

        uint256 numChunks = giveawaySupply / maxPerAddressDuringMint;
        for (uint256 i = 0; i < numChunks; i++) {
            _safeMint(msg.sender, maxPerAddressDuringMint);
        }

        uint256 numModules = giveawaySupply % maxPerAddressDuringMint;
        if (numModules > 0) {
            _safeMint(msg.sender, numModules);
        }
    }

    /**
     * @dev   Admin mint for allocated NFTs
     * @param _amount Number of NFTs to mint
     * @param _to NFT receiver
     */
    function mintAdmin(uint256 _amount, address _to) external onlyOwner {
        require(totalSupply() >= giveawaySupply, "Giveaway not minted");
        require(totalSupply() + _amount <= maxSupply, "Max supply reached");

        uint256 numChunks = _amount / maxPerAddressDuringMint;
        for (uint256 i = 0; i < numChunks; i++) {
            _safeMint(_to, maxPerAddressDuringMint);
        }

        uint256 numModules = _amount % mintLimit;
        if (numModules > 0) {
            _safeMint(_to, numModules);
        }
    }

    /**
     * @param _account Leaf for MerkleTree
     */
    function _leaf(address _account) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account));
    }

    function _verifyWhitelist(bytes32 leaf, bytes32[] memory _proof)
        private
        view
        returns (bool)
    {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 proofElement = _proof[i];

            if (computedHash < proofElement) {
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        return computedHash == _merkleRoot;
    }

    /**
     * @param _amount Number of nfts to mint for whitelist
     * @param _proof Array of values generated by Merkle tree
     */
    function whitelistMint(uint256 _amount, bytes32[] memory _proof)
        external
        payable
    {
        require(presaleStarted, "Not started presale mint");
        require(totalSupply() >= giveawaySupply, "Giveaway not minted");
        require(
            _verifyWhitelist(_leaf(msg.sender), _proof) == true,
            "Invalid Address"
        );
        require(
            _amount > 0 &&
                numberMinted(msg.sender) + _amount <= mintLimitForPreSale,
            "Max limit per wallet exceeded"
        );
        require(
            totalSupply() + _amount <= supplyForPreSale,
            "Max supply reached"
        );

        if (msg.sender != owner()) {
            require(
                msg.value >= preSalePrice * _amount,
                "Need to send more ETH"
            );
        }

        _safeMint(msg.sender, _amount);
        _refundIfOver(preSalePrice * _amount);
    }

    /**
     * @param _amount numbers of NFT to mint for public sale
     */
    function publicSaleMint(uint256 _amount) external payable callerIsUser {
        require(saleStarted, "PUBLIC_MINT_NOT_STARTED");
        require(totalSupply() >= giveawaySupply, "Giveaway not minted");
        require(totalSupply() + _amount <= maxSupply, "reached max supply");
        require(
            numberMinted(msg.sender) + _amount <= mintLimit,
            "can not mint this many"
        );

        if (msg.sender != owner()) {
            require(
                msg.value >= publicSalePrice * _amount,
                "Need to send more ETH"
            );
        }

        uint256 numChunks = _amount / maxPerAddressDuringMint;
        for (uint256 i = 0; i < numChunks; i++) {
            _safeMint(msg.sender, maxPerAddressDuringMint);
        }

        uint256 numModules = _amount % mintLimit;
        if (numModules > 0) {
            _safeMint(msg.sender, numModules);
        }
        _refundIfOver(publicSalePrice * _amount);
    }

    function _refundIfOver(uint256 _price) private {
        if (msg.value > _price) {
            payable(msg.sender).transfer(msg.value - _price);
        }
    }

    /**
     * Override tokenURI
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "Not exist token");

        if (revealed == false) {
            return notRevealedURI;
        } else {
            string memory currentBaseURI = _baseURI();
            return
                bytes(currentBaseURI).length > 0
                    ? string(
                        abi.encodePacked(
                            currentBaseURI,
                            _tokenId.toString(),
                            baseExtension
                        )
                    )
                    : "";
        }
    }

    function withdraw() external onlyOwner nonReentrant {
        require(payable(msg.sender).send(address(this).balance));
    }

    function setSaleStarted(bool _hasStarted) external onlyOwner {
        require(saleStarted != _hasStarted, "already initialized");
        saleStarted = _hasStarted;
    }

    function setpresaleStarted(bool _hasStarted) external onlyOwner {
        require(presaleStarted != _hasStarted, "already initialized");
        presaleStarted = _hasStarted;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function reveal() public onlyOwner {
        revealed = true;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    function setMerkleRoot(bytes32 _merkleRootValue)
        external
        onlyOwner
        returns (bytes32)
    {
        _merkleRoot = _merkleRootValue;
        return _merkleRoot;
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId)
        external
        view
        returns (TokenOwnership memory)
    {
        return ownershipOf(tokenId);
    }
}
