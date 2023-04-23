// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Open Zeppelin:

// Open Zeppelin NFT guide:
// https://docs.openzeppelin.com/contracts/4.x/erc721

// Open Zeppelin ERC721 contract implements the ERC-721 interface and provides
// methods to mint a new NFT and to keep track of token ids.
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol

// Open Zeppelin ERC721URIStorage extends the standard ERC-721 with methods
// to hold additional metadata.
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
// TODO:
// Other openzeppelin contracts might be useful. Check the Utils!
// https://docs.openzeppelin.com/contracts/4.x/utilities


// Local imports:

// TODO:
// You might need to adjust paths to import accordingly.

// Import BaseAssignment.sol
import "../BaseAssignment.sol";

// Import INFTMINTER.sol
import "./INFTMINTER.sol";

// You contract starts here:
// You need to inherit from multiple contracts/interfaces.
contract Assignment1 is INFTMINTER, ERC721URIStorage, BaseAssignment {

    using SafeMath for uint256;
    using Strings for uint256;
    
    // TODO: 
    // Add the ipfs hash of an image that you uploaded to IPFS.
    string IPFSHash = "QmXf3vfHe6JjLdGAj1cFH5H1JVGox5DrAiYz44U9Rw3gvU";

    // Total supply.
    uint256 public totalSupply;

    // Current price. See also: https://www.cryps.info/en/Gwei_to_ETH/1/
    uint256 private price = 0.001 ether; 

    bool saleStatus = true;

    // TODO: 
    // Adjust the Token name and ticker as you like.
    // Very important! The validator address must be passed to the 
    // BaseAssignment constructor (already inserted here).
    constructor()
        ERC721("Token", "TKN")
        BaseAssignment(0x80A2FBEC8E3a12931F68f1C1afedEf43aBAE8541)
    {}
    
    function mint(address _address) public payable override returns (uint256) {
        // 1. First, check if the conditions for minting are met.
        require(msg.value >= price, "Not enough Ether sent to mint NFT");
        require(getSaleStatus(), "Sale is not active");
        // 2. Then increment total supply and price.
        totalSupply = totalSupply + 1;
        price = price + 0.0001 ether;
        // 3. Get the current token id, after incrementing it.
        // Hint: Open Zeppelin has methods for this.
        uint256 tokenId = totalSupply;
        // 4. Mint the token.
        // Hint: Open Zeppelin has a method for this.
        _mint(_address, tokenId);
        // 5. Compose the token URI with metadata info.
        // You might use the helper function getTokenURI.
        // Make sure to keep the data in "memory."
        // Hint: Learn about data locations.
        // https://dev.to/jamiescript/data-location-in-solidity-12di
        // https://solidity-by-example.org/data-locations/
        string memory tokenURI = getTokenURI(tokenId, _address);
        // 6. Set encoded token URI to token.
        // Hint: Open Zeppelin has a method for this.
        _setTokenURI(tokenId, tokenURI);
        // 7. Return the NFT id.
        return tokenId;
    }

    // TODO: 
    // Other methods of the INFTMINTER interface to be added here. 
    // Hint: all methods of an interface are external, but here you might
    // need to adjust them to public.

    function burn(uint256 tokenId) public payable {
        require(
            msg.sender == ownerOf(tokenId),
            "You are not the owner of this NFT."
        );

        _burn(tokenId);
        price = price - 0.0001 ether;
        totalSupply = totalSupply - 1;
    }

    function flipSaleStatus() public override {
       require(isValidator(msg.sender), "Only owner or validator can flip sale status");
        saleStatus = !saleStatus;
    }

    function getSaleStatus() public view override returns (bool) {
        return saleStatus;
    }

    function withdraw(uint256 amount) public override {
        require(isValidator(msg.sender) || msg.sender == _owner , "Only owner or validator can withdraw");
        require(amount <= address(this).balance, "Not enough funds in contract");

        (bool sent, bytes memory data) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function getPrice() public view override returns (uint256) {
        return price;
    }

    function getTotalSupply() public view override returns (uint256) {
        return totalSupply;
    }

    function getIPFSHash() public view override returns (string memory) {
        return IPFSHash;
    }


    /*=============================================
    =                   HELPER                  =
    =============================================*/

    // Get tokenURI for token id
    function getTokenURI(uint256 tokenId, address newOwner)
        public
        view
        returns (string memory)
    {
        // Build dataURI.
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "My beautiful artwork #',
            tokenId.toString(),
            '"', // Name of NFT with id.
            '"hash": "',
            IPFSHash,
            '",', // Define hash of your artwork from IPFS.
            '"by": "',
            getOwner(),
            '",', // Address of creator.
            '"new_owner": "',
            newOwner,
            '"', // Address of new owner.
            "}"
        );

        // Encode dataURI using base64 and return it.
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }

    /*=====         End of HELPER         ======*/
}
