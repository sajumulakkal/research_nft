// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import OpenZeppelin contracts for ERC721, access control, burnable, pausability, counters, royalties, reentrancy protection, and ERC20 interfaces
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/NFTLib.sol";
import "hardhat/console.sol";

// Main contract for Research NFTs
contract ResearchNFT is ERC721URIStorage, Ownable, ERC721Burnable, Pausable, ERC2981, ReentrancyGuard {
    using Counters for Counters.Counter;


    // Constructor initializes the ERC721 contract with name and symbol
    constructor() ERC721("ResearchNFT", "RNFT") {
        // Pass name and symbol to the ERC721 constructor
    }

    uint256 public royaltyPercentage; // Variable to store royalty percentage
    uint256 public royaltyBalance; // Variable to store royalty balance
    Counters.Counter private _tokenIdCounter; // Counter for token IDs

    // Struct to store details for Research NFTs
    struct Research {
        string documentURI; // URI to the research document
        uint256 expiration; // Expiration timestamp of the research
        uint256 accessLevel; // Access level for the research
        address author; // Author address of the research
        uint256 views; // Number of views for the research
    }

struct Bid {
    address bidder;
    uint256 amount;
}
    // Struct to store auction details for NFTs
struct Auction {
    uint256 tokenId;           // Token ID being auctioned
    address highestBidder;     // Address of the highest bidder
    uint256 highestBid;        // The highest bid amount
    bool active;               // Status of the auction (true during bidding)
    bool ended;                // ✅ Add this: Marks if auction is completed
    uint256 bidEndTime;        // End time for the auction
}

// Define a structure to hold certificate data
struct Certificate {
    bool issued;
    uint256 issueTimestamp;
}

// Mapping from tokenId to certificate details
mapping(uint256 => Certificate) public certificates;

    // Enum for NFT types: RESEARCH or REWARD
    enum NFTType { RESEARCH, REWARD }

    // Mappings to store various data related to NFTs, auctions, sales, royalties, etc.
    mapping(uint256 => Research) public researchData; // Mapping to store research data for each token
    mapping(address => bool) public whitelisted; // Mapping for whitelisted addresses
    mapping(address => bool) public merchants; // Mapping for merchants who can mint reward NFTs
    mapping(uint256 => Auction) public auctions; // Mapping to store auction details for each token
    mapping(uint256 => uint256) public sales; // Mapping to store sales data
    mapping(address => uint256) private _royalties; // Mapping to store royalty balances for addresses
    mapping(uint256 => NFTType) public nftTypes; // Mapping to store NFT type (Research or Reward) for each token
    mapping(uint256 => bool) public isSoulbound; // Mapping to mark if an NFT is soulbound
    mapping(uint256 => address) private _royaltyRecipients; // Mapping to store royalty recipients for each token
    mapping(uint256 => address) private _royaltyReceivers; // Mapping to store royalty receivers
    mapping(uint256 => uint256) private _royaltyPercentages; // Mapping to store royalty percentages for each token
    mapping(uint256 => bool) public forSale; 
    mapping(address => bool) private bannedUsers;
    mapping(address => bool) public whitelistedMerchants; // Mapping to store whitelisted merchants
    mapping(uint256 => string) private logs;// Declare a mapping to store logs for each tokenId
    mapping(uint256 => string[]) public updateLogs;
    mapping(address => uint256[]) private _nftsCreatedByAddress; // Mapping to track NFTs created by each address




    // Event declarations for various actions related to NFTs (creation, update, auction, etc.)
    event NFTCreated(uint256 indexed tokenId, string metadataURI);
    event NFTUpdated(uint256 indexed tokenId, string newMetadataURI);
    event DocumentUpdated(uint256 indexed tokenId, string newDocumentURI);
    event AuctionStarted(uint256 indexed tokenId, uint256 startBid, uint256 bidEndTime);
    event AuctionEnded(uint256 indexed tokenId, address winner, uint256 finalPrice);
    event ViewIncremented(uint256 indexed tokenId, uint256 newViewCount);
    event RoyaltiesUpdated(uint256 indexed tokenId, address indexed receiver, uint96 royaltyAmount);
    event NFTPurchased(uint256 indexed tokenId, address buyer, uint256 price);
    event NewBidPlaced(uint256 indexed tokenId, address bidder, uint256 bidAmount);
    //event RewardMinted(uint256 indexed tokenId, address vendor, address employee, string metadataURI);
    event RewardMinted(uint256 indexed tokenId, address indexed vendor, address indexed employee, string metadataURI);


    event MerchantAdded(address indexed merchant);
    event MerchantRemoved(address indexed merchant);
    event Voted(uint256 tokenId, address voter);
    //event SubscriptionExtended(uint256 indexed tokenId, uint256 extraDays);
    // --- Research NFT Creation ---
    // Function to create a Research NFT with associated metadata and document URI
function createResearchNFT(
    string memory metadataURI,
    string memory documentURI,
    uint96 royalty,
    uint256 expiration,
    uint256 accessLevel
) external whenNotPaused {
    uint256 tokenId = _tokenIdCounter.current();
    _mint(msg.sender, tokenId);
    _setTokenURI(tokenId, metadataURI);
    _setTokenRoyalty(tokenId, msg.sender, royalty);

    researchData[tokenId] = Research({
        documentURI: documentURI,
        expiration: expiration,
        accessLevel: accessLevel,
        author: msg.sender,
        views: 0
    });

    // Track the creator of the NFT
    _nftsCreatedByAddress[msg.sender].push(tokenId);

    nftTypes[tokenId] = NFTType.RESEARCH;
    _tokenIdCounter.increment();
    emit NFTCreated(tokenId, metadataURI);
}

function getRoyaltyReceiver(uint256 tokenId) public view returns (address) {
    return _royaltyReceivers[tokenId];
}

    // --- Reward NFT Creation (By Merchant) ---
    // Function to mint a Reward NFT by a merchant for a vendor and an employee
// Declare the RewardMinted event at the contract level


function mintRewardNFT(address vendor, address employee, string memory metadataURI) external whenNotPaused {
    require(merchants[msg.sender], "Only whitelisted merchants can mint");
    require(vendor != address(0) && employee != address(0), "Invalid vendor or employee address");

    uint256 tokenId = _tokenIdCounter.current();
    _mint(employee, tokenId);
    _setTokenURI(tokenId, metadataURI);

    nftTypes[tokenId] = NFTType.REWARD;
    isSoulbound[tokenId] = true;
    uint256 subscriptionExpiration = block.timestamp + 30 days;
    subscriptionEndTime[tokenId] = subscriptionExpiration;
    _tokenIdCounter.increment();

    // Emit the RewardMinted event
    emit RewardMinted(tokenId, vendor, employee, metadataURI);
}




function whitelistMerchant(address merchantAddress) external onlyOwner {
    merchants[merchantAddress] = true;
}
    // --- Admin: Manage Merchants ---
    // Function for the owner to add a merchant to the whitelist
    function addMerchant(address merchant) external onlyOwner {
        require(merchant != address(0), "Invalid address"); // Check valid merchant address
        merchants[merchant] = true; // Add the merchant to the whitelist
        emit MerchantAdded(merchant); // Emit event for adding a merchant
    }

    // Function for the owner to remove a merchant from the whitelist
    function removeMerchant(address merchant) external onlyOwner {
        require(merchants[merchant], "Not a merchant"); // Check if the address is a merchant
        merchants[merchant] = false; // Remove the merchant from the whitelist
        emit MerchantRemoved(merchant); // Emit event for removing a merchant
    }


    // --- Pausable Contract ---
    // Function to pause the contract, can only be called by the contract owner
    function pause() external onlyOwner {
        _pause();  // Pauses the contract functionality (e.g., minting, bidding)
    }

    // Function to unpause the contract, can only be called by the contract owner
    function unpause() external onlyOwner {
        _unpause();  // Resumes the contract functionality after being paused
    }

    // --- View & Metadata Updates ---
    // Function to update the document URI of a Research NFT
    // Only the owner of the NFT can update its document URI
    function updateDocumentURI(uint256 tokenId, string memory newDocumentURI) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not NFT owner");  // Ensures that only the NFT owner can update
        researchData[tokenId].documentURI = newDocumentURI;  // Updates the document URI in the mapping
        emit DocumentUpdated(tokenId, newDocumentURI);  // Emit event for document update
    }

    // Function to update the metadata URI of a Research NFT
    // Only the owner of the NFT can update its metadata URI
    function updateMetadataURI(uint256 tokenId, string memory newMetadataURI) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not NFT owner");  // Ensures that only the NFT owner can update
        _setTokenURI(tokenId, newMetadataURI);  // Sets the new metadata URI for the NFT
        emit NFTUpdated(tokenId, newMetadataURI);  // Emit event for metadata update
    }

    // Function to increment the view count of a Research NFT
    // Increases the view count when someone views the NFT's document
    function incrementViewCount(uint256 tokenId) external whenNotPaused {
        require(_exists(tokenId), "NFT does not exist");  // Ensures the NFT exists before proceeding
        researchData[tokenId].views += 1;  // Increment the view count for the NFT
        emit ViewIncremented(tokenId, researchData[tokenId].views);  // Emit event for view count increment
    }

    // --- Royalties ---
    // Function to set royalties for a specific Research NFT
    // Only the owner of the NFT can set its royalty percentage
    function setRoyalties(uint256 tokenId, uint256 _royaltyPercentage) external {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can set royalties");  // Only the owner can set royalties
        _royaltyReceivers[tokenId] = msg.sender;  // Set the owner as the royalty receiver
        _royaltyPercentages[tokenId] = _royaltyPercentage;  // Set the royalty percentage for the token
    }

// Function to distribute royalties when a sale occurs
// The royalty is transferred to the receiver, and the seller gets the remaining amount
// Function to distribute royalties when a sale occurs
// The royalty is transferred to the receiver, and the seller gets the remaining amount
function distributeRoyalties(uint256 tokenId, uint256 saleAmount) external whenNotPaused {
    // Get the royalty receiver address and the royalty amount
    (address receiver, uint256 royaltyAmount) = royaltyInfo(tokenId, saleAmount);

    if (royaltyAmount > 0) {
        // Ensure the receiver address is payable and transfer the royalty amount
        payable(receiver).transfer(royaltyAmount);

        // Update the royalty balance for the receiver
        _royalties[receiver] += royaltyAmount;
    }

    // Emit the RoyaltiesUpdated event with the updated info
    emit RoyaltiesUpdated(tokenId, receiver, uint96(royaltyAmount));
}

// Function to handle auction bids
// Function to handle auction bids
// Function to handle auction bids
function handleAuctionBid(uint256 tokenId, uint256 bidAmount) external whenNotPaused {
    // Get the royalty receiver address and the royalty amount
    (address receiverAddr, uint256 royaltyAmount) = royaltyInfo(tokenId, bidAmount);

    if (royaltyAmount > 0) {
        // Transfer the royalty to the receiver
        payable(receiverAddr).transfer(royaltyAmount);
        _royalties[receiverAddr] += royaltyAmount;
    }
}

// Function to handle direct sale of an NFT
function handleSale(uint256 tokenId) external payable whenNotPaused {
    // Get the royalty receiver address and the royalty amount for the sale
    (address receiverAddr, uint256 royaltyAmount) = royaltyInfo(tokenId, msg.value);

    if (royaltyAmount > 0) {
        // Transfer the royalty amount to the receiver
        payable(receiverAddr).transfer(royaltyAmount);

        // Update the royalty balance
        _royalties[receiverAddr] += royaltyAmount;
    }
}





    // --- Auctions ---
    // Function to start an auction for an NFT
    // The auction is only valid if the caller is the owner and the auction is not already active
    // function startAuction(uint256 tokenId, uint256 startBid, uint256 duration) external whenNotPaused {
function startAuction(uint256 tokenId, uint256 startBid, uint256 duration) external whenNotPaused {
    require(_exists(tokenId), "ERC721: token does not exist");
    require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
    require(!auctions[tokenId].active, "Auction already active");
    require(duration > 0, "Duration must be greater than 0");

    auctions[tokenId] = Auction({
        tokenId: tokenId,
        highestBidder: address(0),
        highestBid: startBid,
        active: true,
        bidEndTime: block.timestamp + duration,
        ended: false
    });

    emit AuctionStarted(tokenId, startBid, auctions[tokenId].bidEndTime);
}




    // Function to place a bid on an active auction
    // Ensures that the bid is higher than the current highest bid and that the auction is still active
function placeBid(uint256 tokenId) external payable whenNotPaused nonReentrant {
    Auction storage auction = auctions[tokenId];
    
    // Ensure the token exists
    require(_exists(tokenId), "ERC721: token does not exist");
    
    require(auction.active, "Auction not active");
    require(msg.value > auction.highestBid, "Bid too low");
    require(block.timestamp < auction.bidEndTime, "Auction ended");

    if (auction.highestBidder != address(0)) {
        payable(auction.highestBidder).transfer(auction.highestBid);  // Refund the previous highest bidder
    }

    auction.highestBidder = msg.sender;
    auction.highestBid = msg.value;
    auction.bidEndTime = block.timestamp + 30 minutes;  // Extend auction time

    emit NewBidPlaced(tokenId, msg.sender, msg.value);
}

function endAuction(uint256 tokenId) external whenNotPaused nonReentrant {
    Auction storage auction = auctions[tokenId];

    // Ensure that the auction is active and the auction end time has passed
    require(auction.active, "Auction not active");
    require(block.timestamp >= auction.bidEndTime, "Auction not ended");

    // ✅ Ensure only the NFT owner can end the auction
    require(msg.sender == ownerOf(tokenId), "Not NFT owner");

    auction.active = false;  // Mark the auction as no longer active
    auction.ended = true;    // Mark the auction as fully ended (new field)

    address seller = ownerOf(tokenId);  // The seller is the current owner of the NFT

    // Proceed only if there is a highest bidder
    if (auction.highestBidder != address(0)) {
        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, auction.highestBid);
        uint256 sellerAmount = auction.highestBid - royaltyAmount;  // Amount to be paid to the seller

        // Transfer the royalty amount if applicable
        if (royaltyAmount > 0) {
            payable(royaltyReceiver).transfer(royaltyAmount);
            _royalties[royaltyReceiver] += royaltyAmount;  // Update the royalty balance
        }

        // Transfer the remaining amount to the seller
        payable(seller).transfer(sellerAmount);

        // Transfer the NFT ownership to the highest bidder
        _transfer(seller, auction.highestBidder, tokenId);
    }

    // Emit event for the auction's end, including the highest bidder and bid amount
    emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
}



// --- Direct Sale ---
    // Sets an NFT for sale with a specified price. Only the owner of the token can set the price.
    //function setForSale(uint256 tokenId, uint256 price) external whenNotPaused {
function setForSale(uint256 tokenId, uint256 price) external {
    // Ensure the caller is the owner of the NFT
    require(ownerOf(tokenId) == msg.sender, "Only the owner can set the NFT for sale");

    // Check if the NFT has been sold at auction and prevent re-sale if auction has ended
    Auction storage auction = auctions[tokenId];
    require(auction.ended == false, "NFT already sold at auction");  // Check that auction is not ended

    // Ensure the price is valid (greater than zero)
    require(price > 0, "Price must be greater than zero");

    // Ensure the NFT is not currently being auctioned
    require(!auction.active, "Cannot set for sale during auction");  // Prevent sale during an active auction

    // Mark the NFT as for sale and store the price
    forSale[tokenId] = true;
    sales[tokenId] = price;
}


function isForSale(uint256 tokenId) external view returns (bool) {
    return forSale[tokenId];
}
    // Allows a user to buy an NFT, transferring ownership and handling payments.
    function buyNFT(uint256 tokenId) external payable nonReentrant {
        uint256 price = sales[tokenId];  // Get the price of the NFT for sale
        require(price > 0, "NFT not for sale");  // Check if the NFT is available for sale
        require(msg.value >= price, "Insufficient payment");  // Ensure the buyer sends enough ETH

        address seller = ownerOf(tokenId);  // Get the current owner of the NFT
        require(seller != msg.sender, "Cannot buy your own NFT");  // Prevent the owner from buying their own NFT

        (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(tokenId, msg.value);  // Get the royalty info for the sale
        uint256 sellerAmount = msg.value - royaltyAmount;  // Calculate the amount to transfer to the seller

        if (royaltyAmount > 0) {
            payable(royaltyReceiver).transfer(royaltyAmount);  // Pay royalties to the creator
            _royalties[royaltyReceiver] += royaltyAmount;  // Track the royalty payment
        }

        payable(seller).transfer(sellerAmount);  // Pay the seller for the NFT
        _transfer(seller, msg.sender, tokenId);  // Transfer ownership of the NFT to the buyer

        emit NFTPurchased(tokenId, msg.sender, price);  // Emit an event for the purchase
    }

    // --- Override supportsInterface ---
    // This function overrides the ERC721, ERC721URIStorage, and ERC2981 contracts to support interfaces
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);  // Call the parent contract's supportsInterface function
    }

    // Overrides the tokenURI function to return the token URI from ERC721URIStorage
    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);  // Returns the token URI from ERC721URIStorage
    }

    // Overrides the _burn function to ensure the token is correctly burned
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);  // Calls the _burn function from ERC721URIStorage to handle the burning logic
    }

    // Checks if the token has expired by comparing the current block timestamp with the expiration time
function isExpired(uint256 tokenId) public view returns (bool) {
    return block.timestamp > subscriptionEndTime[tokenId];  // Check the correct expiration mapping
}

    // Allows users to withdraw their earned royalties from the contract
    function withdrawRoyalties() external nonReentrant {
        uint256 amount = _royalties[msg.sender];  // Get the royalty balance for the sender
        require(amount > 0, "No royalties to withdraw");  // Ensure the sender has royalties to withdraw

        _royalties[msg.sender] = 0;  // Reset the sender's royalty balance
        payable(msg.sender).transfer(amount);  // Transfer the royalties to the sender
    }

function royaltyInfo(uint256 tokenId, uint256 salePrice) 
    public 
    view 
    override 
    returns (address receiver, uint256 royaltyAmount) 
{
    require(_exists(tokenId), "ERC721: invalid token ID"); // ✅ Check if token exists

    receiver = _royaltyReceivers[tokenId];
    uint256 royaltyPercent = _royaltyPercentages[tokenId];
    royaltyAmount = (salePrice * royaltyPercent) / 10000;
}


    //1. Mint Multiple Research NFTs in a Single Transaction
// Allows the creation of multiple Research NFTs in one transaction
function createMultipleResearchNFTs(
    string[] memory metadataURIs,
    string[] memory documentURIs,
    uint96[] memory royalties,
    uint256[] memory expirations,
    uint256[] memory accessLevels
) external whenNotPaused {
    require(metadataURIs.length == documentURIs.length, "Array lengths mismatch");
    require(documentURIs.length == royalties.length, "Array lengths mismatch");
    require(royalties.length == expirations.length, "Array lengths mismatch");
    require(expirations.length == accessLevels.length, "Array lengths mismatch");

    for (uint256 i = 0; i < metadataURIs.length; i++) {
        uint256 tokenId = _tokenIdCounter.current();

        // Mint the NFT
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataURIs[i]);
        _setTokenRoyalty(tokenId, msg.sender, royalties[i]);

        // Set up research data
        researchData[tokenId] = Research({
            documentURI: documentURIs[i],
            expiration: expirations[i],
            accessLevel: accessLevels[i],
            author: msg.sender,
            views: 0
        });

        // Track the creator for each NFT
        _nftsCreatedByAddress[msg.sender].push(tokenId);

        // Set the type as Research
        nftTypes[tokenId] = NFTType.RESEARCH;

        // Increment counters
        _tokenIdCounter.increment();
        _totalSupply += 1; // Increment total supply

        // Emit the event
        emit NFTCreated(tokenId, metadataURIs[i]);
    }
}

function getNFTsCreatedBy(address creator) external view returns (uint256[] memory) {
    return _nftsCreatedByAddress[creator];
}

    //4. Transfer Ownership of an NFT and Pay Royalties to the Original Creator
    // Transfers ownership of an NFT and pays royalties to the original creator
    function transferWithRoyalties(uint256 tokenId, address to) external payable nonReentrant {
        address creator = _royaltyReceivers[tokenId];  // Get the creator of the NFT
        uint256 royaltyAmount = _royaltyPercentages[tokenId] * msg.value / 10000;  // Calculate the royalty amount based on the payment

        // Transfer royalties to the creator if applicable
        if (royaltyAmount > 0) {
            payable(creator).transfer(royaltyAmount);  // Pay the creator their royalty amount
        }

        // Transfer the NFT to the new owner
        _transfer(msg.sender, to, tokenId);  // Transfer the NFT from the sender to the new owner
    }
// 5. Check if Caller has Access to the Research Document
// Add this to your function for debugging
// 5. Check if Caller has Access to the Research Document
function hasAccess(uint256 tokenId) public view returns (bool) {
    require(_exists(tokenId), "Token does not exist");

    // Debugging
    console.log("Current Time:", block.timestamp);
    console.log("Expiration Time:", researchData[tokenId].expiration);
    
    return block.timestamp <= researchData[tokenId].expiration;
}



// 6. Retrieve Access Level of the Research Document
function getAccessLevel(uint256 tokenId) external view returns (uint256) {
    // This function returns the access level of the research document associated with the tokenId.
    return researchData[tokenId].accessLevel;
}

// 7. Renew Subscription for an NFT by Updating its Expiration Date
function renewSubscription(uint256 tokenId, uint256 newExpiration) external {
    // This function allows the owner of an NFT to renew the subscription by updating its expiration date.
    require(ownerOf(tokenId) == msg.sender, "Not NFT owner");  // Ensure the caller is the owner of the NFT.
    researchData[tokenId].expiration = newExpiration;
}

// 8. Revoke Access by Burning the NFT
function burnNFT(uint256 tokenId) public {
    // This function allows the owner to revoke access to the research document by burning the NFT.
    require(ownerOf(tokenId) == msg.sender, "Not NFT owner");  // Ensure the caller is the owner of the NFT.
    _burn(tokenId);  // Burn the token to revoke access.
}


// 9. Stake Tokens
mapping(address => uint256) public stakedTokens;  // Mapping to track staked tokens per address.

IERC20 public stakingToken;  // ERC20 token to stake



event TokensStaked(address indexed user, uint256 amount);

function stakeTokens(uint256 amount) external nonReentrant {
    require(amount > 0, "Amount must be > 0");

    // Transfer tokens before updating state to prevent reentrancy
    bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
    require(success, "Token transfer failed");

    stakedTokens[msg.sender] += amount;

    emit TokensStaked(msg.sender, amount);
}

function unstakeTokens(uint256 amount) external {
    // This function allows users to unstake tokens from the contract.
    require(stakedTokens[msg.sender] >= amount, "Not enough staked");  // Ensure the user has enough staked tokens.
    stakedTokens[msg.sender] -= amount;  // Reduce the staked amount for the user.
    stakingToken.transfer(msg.sender, amount);  // Transfer the unstaked tokens back to the user.
}

function withdrawStakedTokens(uint256 amount) external {
    // This function allows users to withdraw staked tokens.
    require(stakedTokens[msg.sender] >= amount, "Insufficient staked tokens");  // Ensure sufficient staked balance.
    stakedTokens[msg.sender] -= amount;  // Update the staked amount for the user.
    require(stakingToken.transfer(msg.sender, amount), "Transfer failed");  // Ensure the withdrawal transfer is successful.
}

// 10. Reward Users for Referrals
mapping(address => address) public referrals;  // Mapping to track referrals for each user.
mapping(address => uint256) public referralRewards;  // Mapping to track rewards for each referrer.

function setReferral(address referrer) external {
    // This function allows users to set a referrer address for the referral system.
    require(referrals[msg.sender] == address(0), "Already referred");  // Ensure the user hasn't already been referred.
    referrals[msg.sender] = referrer;  // Set the referrer address for the user.
}

function rewardReferral(address referrer, uint256 rewardAmount) external {
    // This function rewards the referrer with a certain amount of tokens.
    referralRewards[referrer] += rewardAmount;  // Increase the referrer's reward balance.
}

// 11. Calculate and Return Dynamic Price of an NFT Based on Views
function getDynamicPrice(uint256 tokenId) public view returns (uint256) {
    uint256 views = researchData[tokenId].views;
    return 100 * views;
}

// 13. Track Readership Count for Research NFTs
// Placeholder for tracking readership count. This can be implemented as a mapping or counter depending on requirements.

// 14. Add/Remove Address from Whitelist
function addToWhitelist(address account) external onlyOwner {
    // This function adds an address to the whitelist.
    whitelisted[account] = true;
}

function removeFromWhitelist(address account) external onlyOwner {
    // This function removes an address from the whitelist.
    whitelisted[account] = false;
}

// 15. Permanently Remove an NFT from Circulation by Burning
// Placeholder for burning logic. This could be implemented similarly to the burnNFT function.

// 16. Transfer Ownership of the Contract to Another Address
function transferOwnershipOfContract(address newOwner) external onlyOwner {
    // This function allows the contract owner to transfer ownership to another address.
    transferOwnership(newOwner);
}

// 17. Purchase License to Use Research Content
function purchaseLicense(uint256 tokenId) external payable {
    uint256 price = sales[tokenId];
    require(price > 0, "Token not for sale");
    require(msg.value >= price, "Insufficient funds");

    address seller = ownerOf(tokenId);
    require(seller != address(0), "Invalid seller");

    // Transfer payment to the seller
    payable(seller).transfer(msg.value);

    // Transfer the NFT to the buyer
    _transfer(seller, msg.sender, tokenId);

    // Clear the sale listing
    sales[tokenId] = 0;
}


// 18. Provide Feedback and Rate the Quality of the Research Content
mapping(uint256 => string) public feedback;  // Mapping to store feedback for each research document.

function provideFeedback(uint256 tokenId, string memory contentFeedback) external {
    // This function allows users to provide feedback for a specific research document.
    feedback[tokenId] = contentFeedback;  // Store the feedback for the given tokenId.
}

// 19. Share Access to the Research Content with Others (Temporarily or Permanently)
// Declare the AccessShared event
event AccessShared(uint256 indexed tokenId, address indexed recipient);

// Function to share access with others
using Counters for Counters.Counter;


function shareAccess(uint256 tokenId, address recipient) external {
    require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
    require(_exists(tokenId), "Original token doesn't exist");

    // Get new token ID
    uint256 newTokenId = _tokenIdCounter.current();

    // Mint new token to recipient
    _mint(recipient, newTokenId);

    // Optionally, copy metadata or research data from original token
    _setTokenURI(newTokenId, tokenURI(tokenId)); // if using tokenURI
    researchData[newTokenId] = researchData[tokenId];
    nftTypes[newTokenId] = NFTType.RESEARCH;

    _tokenIdCounter.increment(); // Increment after use

    emit AccessShared(tokenId, recipient);
}

// 20. Customize Research Content Based on Preferences
function customizeResearch(uint256 tokenId, string memory newMetadata) external {
    // This function allows the owner of the NFT to customize the metadata associated with the research document.
    require(ownerOf(tokenId) == msg.sender, "Not NFT owner");  // Ensure the caller is the owner of the NFT.
    _setTokenURI(tokenId, newMetadata);  // Update the metadata for the research document.
}
// Modify transferFrom to add a check for ongoing auctions
    // Override transferFrom to add the auction check
// Specify that the function is overriding the ERC721 and IERC721 contracts
function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721) {
    // Ensure that the NFT is not being transferred during an auction
    Auction storage auction = auctions[tokenId];
    require(!auction.active, "Cannot transfer during auction");

    // Proceed with the standard transfer logic
    super.transferFrom(from, to, tokenId);
}


// 21. Manage Subscriptions (Upgrade, Downgrade, Cancel)
function manageSubscription(uint256 tokenId, uint256 newAccessLevel, uint256 newExpiration) external {
    // This function allows the NFT owner to manage their subscription by upgrading/downgrading access level and updating expiration.
    require(ownerOf(tokenId) == msg.sender, "Not NFT owner");  // Ensure the caller is the owner of the NFT.
    researchData[tokenId].accessLevel = newAccessLevel;  // Update the access level.
    researchData[tokenId].expiration = newExpiration;  // Update the expiration date.
}

// 22. Notify Users about Important Updates (Research Content, Renewals, etc.)
function getReferralStats(address referrer) external view returns (uint256 reward) {
    // This function retrieves the referral stats for a specific referrer, showing the total reward earned.
    return referralRewards[referrer];
}

// 24. Archive Older Research Content for Users with Appropriate Permissions
function archiveResearch(uint256 tokenId) external {
    // This function archives older research content by burning the NFT if the caller has access.
    require(hasAccess(tokenId), "No access to archive");  // Ensure the caller has access to the research document.
    burnNFT(tokenId);  // Burn the NFT to archive the content.
}

 
// 25. Track User Behavior and Engagement with Content
// for tracking user behavior and engagement with content. This could be implemented as an event or counter.
// Event to track user engagement
event UserEngaged(address indexed user, uint256 indexed tokenId, string action);
function trackEngagement(address user, uint256 tokenId, string memory action) external {
    // Emit an event to track user interaction
    emit UserEngaged(user, tokenId, action);
}

// 26. Execute Multi-Signature Transactions for Important Actions
// Multi-Signature contract placeholder

// ===== Multi-Signature Logic for Important Actions =====

// Event emitted when an owner approves an action
event MultiSigApproval(address indexed approver, uint256 indexed actionId);

// Counter for action IDs (can be used in your multi-sig workflow)
uint256 public actionCount;

// Mapping of action approvals: actionId => (owner address => bool)
mapping(uint256 => mapping(address => bool)) public approvals;

// List of owner addresses who can approve actions
address[] public owners;

// Internal mapping to quickly check ownership
mapping(address => bool) private _isResearchOwner;

// Custom modifier (avoid clashing with OpenZeppelin's onlyOwner)
modifier onlyResearchOwner() {
    require(_isResearchOwner[msg.sender], "Not a research owner");
    _;
}


// Function to check if an address is a research owner
function isResearchOwner(address account) public view returns (bool) {
    return _isResearchOwner[account];
}

// Function to add a new research owner (only callable by the main contract owner)
event NewResearchOwner(address newOwner);

function addResearchOwner(address newOwner) external onlyOwner {
    require(!_isResearchOwner[newOwner], "Already a research owner");
    owners.push(newOwner);
    _isResearchOwner[newOwner] = true;
    emit NewResearchOwner(newOwner); // Emit the event
}


// Function for an owner to approve an action
function approveAction(uint256 actionId) external onlyResearchOwner {
    approvals[actionId][msg.sender] = true;
    emit MultiSigApproval(msg.sender, actionId);
}

// Function to execute an action if enough approvals are collected
// Function to execute an action if enough approvals are collected


    // Function to execute an action if enough approvals are collected.
    // Marked as view since currently no state change is done.
// Function to execute an action if majority of research owners approve it
function executeAction(uint256 actionId) external view onlyResearchOwner {
    uint256 approvalCount = 0;
    for (uint256 i = 0; i < owners.length; i++) {
        if (approvals[actionId][owners[i]]) {
            approvalCount++;
        }
    }
    require(approvalCount > owners.length / 2, "Majority approval not met");
}



// 27. Preview Portion of Research Content Before Purchase
// Placeholder for preview logic. This can be implemented based on the specifics of the research content.
// Mapping of tokenId to preview URL
mapping(uint256 => string) public contentPreviews;

function setPreview(uint256 tokenId, string memory previewUrl) external onlyOwner {
    contentPreviews[tokenId] = previewUrl;
}

function getPreview(uint256 tokenId) external view returns (string memory) {
    return contentPreviews[tokenId];
}

// 28. Bundle Multiple Research Reports into a Single NFT

// Declare the event for bundling NFTs
event NFTsBundled(uint256 indexed newTokenId, uint256[] tokenIds);

// Function to bundle multiple NFTs into a single NFT
function bundleNFTs(uint256[] memory tokenIds) external {
    // Logic to bundle NFTs together into a single NFT
    uint256 newTokenId = _createBundleNFT(tokenIds);
    emit NFTsBundled(newTokenId, tokenIds);
}

// Internal function to create a bundled NFT
// Declare the mapping at the contract level (outside functions)
mapping(uint256 => uint256[]) public bundles;

// Internal function to create a bundled NFT
function _createBundleNFT(uint256[] memory tokenIds) private returns (uint256) {
    // Mint the new bundle NFT using a helper function
    uint256 bundleTokenId = _mintBundleNFT();
    
    // Link the original tokenIds to the new bundle NFT
    bundles[bundleTokenId] = tokenIds;
    
    return bundleTokenId;
}


// Helper function to mint a new NFT for the bundle
function _mintBundleNFT() private returns (uint256) {
    uint256 tokenId = _tokenIdCounter.current();  // Assuming you're using a counter (from OpenZeppelin Counters)
    _mint(msg.sender, tokenId);                   // Mint the NFT to the caller (or adjust as needed)
    _setTokenURI(tokenId, "ipfs://bundle_metadata_uri"); // Optionally set a token URI for the bundle
    _tokenIdCounter.increment();                  // Increment the counter for the next token
    return tokenId;
}


// Declare the event for revoking access (place this at the top with your other event declarations)
event AccessRevoked(uint256 indexed tokenId);
// 29. Revoke Access for Users Violating Terms of Service
// This function revokes access by burning the NFT.
function revokeAccess(uint256 tokenId) external onlyOwner {
    // Logic to burn the NFT or revoke its access
    _burn(tokenId);  // Burning the token
    emit AccessRevoked(tokenId);
}
// 30. Verify the Authenticity of the Research Content by Third-Party Experts
// Placeholder for authenticity verification logic. This could involve integration with third-party services or experts.
// Event to verify authenticity
event ContentVerified(uint256 indexed tokenId, bool isAuthentic);

function verifyAuthenticity(uint256 tokenId, bool isAuthentic) external onlyOwner {
    // Integrate with third-party service or logic for verification
    emit ContentVerified(tokenId, isAuthentic);
}
// 31. Translate Research Content into Multiple Languages
// translation functionality. This could involve external services for translating content into various languages.
// Mapping to store content translations
mapping(uint256 => mapping(string => string)) public contentTranslations;

function setTranslation(uint256 tokenId, string memory language, string memory translatedContent) external onlyOwner {
    contentTranslations[tokenId][language] = translatedContent;
}

function getTranslation(uint256 tokenId, string memory language) external view returns (string memory) {
    return contentTranslations[tokenId][language];
}

// 32. Control Access to Specific Sections of the Document Based on User's Access Level
// Placeholder for controlling access to specific sections. This could involve smart contract logic to check the user's access level.

mapping(uint256 => mapping(address => uint256)) public userAccessLevel;

function setUserAccessLevel(uint256 tokenId, address user, uint256 level) external onlyOwner {
    userAccessLevel[tokenId][user] = level;
}

function getUserAccessLevel(uint256 tokenId, address user) external view returns (uint256) {
    return userAccessLevel[tokenId][user];
}
// 33. Upgrade/Downgrade Subscription for an NFT by Adjusting Access Level
// Placeholder for upgrading/downgrading functionality. This could involve logic to adjust the access level of the NFT.
// Function to get the royalty receiver for a given token ID
// Mapping declaration
// Event declaration
event AccessLevelUpdated(uint256 indexed tokenId, address indexed user, uint256 newLevel);

// Function to upgrade
function upgradeSubscription(uint256 tokenId, uint256 newLevel) external {
    require(ownerOf(tokenId) == msg.sender, "Not the token owner");
    userAccessLevel[tokenId][msg.sender] = newLevel;
    emit AccessLevelUpdated(tokenId, msg.sender, newLevel);
}

// Function to downgrade
function downgradeSubscription(uint256 tokenId, uint256 newLevel) external {
    require(ownerOf(tokenId) == msg.sender, "Not the token owner");
    userAccessLevel[tokenId][msg.sender] = newLevel;
    emit AccessLevelUpdated(tokenId, msg.sender, newLevel);
}
function getBundle(uint256 tokenId) public view returns (uint256[] memory) {
    return bundles[tokenId];
}

//Track readership count for Research NFTs
    mapping(uint256 => uint256) private _readershipCount;

    //event ResearchViewed(uint256 indexed tokenId, address indexed viewer, uint256 newCount);
    event ResearchViewed(uint256 indexed tokenId, address indexed viewer, uint256 views);

function viewResearch(uint256 tokenId) public {
    require(_exists(tokenId), "ResearchNFT: View query for nonexistent token");

    // Increment both the general view count and the per-token view count
    _readershipCount[tokenId] += 1;
    researchData[tokenId].views += 1;

    emit ResearchViewed(tokenId, msg.sender, researchData[tokenId].views);
}



    function getReadershipCount(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ResearchNFT: Count query for nonexistent token");
        return _readershipCount[tokenId];
    }
// 
    using NFTLib for NFTLib.Data;

    NFTLib.Data private nftData;
 
    function addFeedback(uint256 tokenId, address user, uint8 rating, string memory comment) public {
        nftData.addFeedback(tokenId, user, rating, comment);
    }

    function getFeedback(uint256 tokenId) public view returns (NFTLib.Feedback[] memory) {
        return nftData.getFeedback(tokenId);
    }

    function getAverageRating(uint256 tokenId) public view returns (uint256) {
        return nftData.getAverageRating(tokenId);
    }
    // Function to add a comment
    function addComment(uint256 tokenId, string memory content) public {
        require(_exists(tokenId), "Token does not exist");
        nftData.addComment(tokenId, msg.sender, content);  // Add comment using NFTLib
    }

    // Function to get all comments for a token
    function getComments(uint256 tokenId) external view returns (NFTLib.Comment[] memory) {
        return nftData.getComments(tokenId);  // Retrieve comments using NFTLib
    }

    // Example: Implement _exists() to check token existence
    //function _exists(uint256 tokenId) internal view override returns (bool) {
    // return super._exists(tokenId); // Calls the _exists function from ERC721
    //}
  // 1. Vote to promote quality research
    function voteForResearch(uint256 tokenId, uint8 rating, string memory comment) public {
        require(_exists(tokenId), "Token does not exist");
        nftData.addFeedback(tokenId, msg.sender, rating, comment);
    }

    // 2. Award tokens for research engagement
    function awardTokens(uint256 tokenId, address recipient, uint256 amount) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        nftData.distributeReward(tokenId, recipient, amount);
    }

mapping(address => uint256) private _engagementTokens;

function rewardEngagement(address user, uint256 amount) public onlyOwner {
    require(user != address(0), "Invalid address");
    _engagementTokens[user] += amount;
}

function tokenBalance(address user) public view returns (uint256) {
    return _engagementTokens[user];
}

    // 3. List NFTs for sale
    function listNFTForSale(uint256 tokenId, uint256 price) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        nftData.listNFT(tokenId, price);
    }

    // 4. Delist NFTs from sale
    function delistNFT(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        nftData.delistNFT(tokenId);
    }

    // 5. Update sale price of NFT
    function updateNFTSalePrice(uint256 tokenId, uint256 newPrice) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        nftData.updateSalePrice(tokenId, newPrice);
    }

    // 6. View NFTs on sale
    function getNFTSaleInfo(uint256 tokenId) public view returns (bool listed, uint256 price) {
        return nftData.getSaleInfo(tokenId);
    }

uint256 private _totalSupply = 0;

function totalSupply() public view returns (uint256) {
    return _totalSupply;
}
// 6. View NFTs on sale
// Assuming you are calling this function correctly in the test.


// Assuming totalSupply() is a function that returns the total number of NFTs minted
function getNFTsOnSale() public view returns (uint256[] memory) {
    uint256 totalSupplyCount = totalSupply();  // Call totalSupply() to get the total number of NFTs minted
    uint256[] memory onSaleTokens = new uint256[](totalSupplyCount);
    uint256 index = 0;

    // Loop through all tokens and check if they are on sale
    for (uint256 i = 0; i < totalSupplyCount; i++) {
        (bool listed, ) = getNFTSaleInfo(i);  // Use the existing function to check if an NFT is on sale
        if (listed) {
            onSaleTokens[index] = i;
            index++;
        }
    }

    // Resize the array to fit the actual number of tokens on sale
    uint256[] memory finalOnSaleTokens = new uint256[](index);
    for (uint256 i = 0; i < index; i++) {
        finalOnSaleTokens[i] = onSaleTokens[i];
    }

    return finalOnSaleTokens;
}


    // 7. Retrieve all active research NFTs
function getActiveResearchNFTs(uint256[] memory allTokenIds) public view returns (uint256[] memory) {
    uint256[] memory activeNFTs = new uint256[](allTokenIds.length);
    uint256 count = 0;

    for (uint256 i = 0; i < allTokenIds.length; i++) {
        uint256 tokenId = allTokenIds[i];
        
        // Check if the NFT is active (e.g., checking if it is not soulbound)
        if (!isSoulbound[tokenId] && nftTypes[tokenId] == NFTType.RESEARCH) {
            activeNFTs[count] = tokenId;
            count++;
        }
    }

    // Resize the array to match the count of active NFTs
    uint256[] memory result = new uint256[](count);
    for (uint256 i = 0; i < count; i++) {
        result[i] = activeNFTs[i];
    }
    
    return result;
}
// Example of a getter function for _tokenIdCounter
function getTokenIdCounter() public view returns (uint256) {
    return _tokenIdCounter.current();
}



    // 8. Ban a user from interacting with NFTs
function banUser(address user) public {
    bannedUsers[user] = true;
}

function isBanned(address user) public view returns (bool) {
    return bannedUsers[user];
}
    // 9. Issue certificate after subscription expiration
    // Function to issue the certificate after subscription expiration
// Event to emit when a certificate is issued

// Event for debugging purposes
event DebugEvent(uint256 tokenId, uint256 currentTime, uint256 subscriptionEndTime);
// Define the event for logging

event CertificateIssued(uint256 tokenId);

// Define the event with 4 arguments
event Log(string message, uint256 tokenId, uint256 currentTime, uint256 subscriptionEndTime);


 
// Function to issue the certificate after subscription expiration
// Function to issue the certificate after subscription expiration
function issueCertificate(uint256 tokenId) public {
    require(_exists(tokenId), "Token does not exist");
 



    address tokenOwner = ownerOf(tokenId);
    require(msg.sender == ownerOf(tokenId), "Only token owner can issue certificate");

    uint256 currentTime = block.timestamp;
    uint256 subscriptionEnd = subscriptionEndTime[tokenId];
    emit Log("Current time", tokenId, currentTime, subscriptionEnd);

    require(currentTime >= subscriptionEnd, "Subscription has not expired");
    
    require(!certificates[tokenId].issued, "Certificate already issued");
    
    emit Log("Issuing certificate", tokenId, currentTime, 0);

    certificates[tokenId] = Certificate({
        issued: true,
        issueTimestamp: currentTime
    });

    emit CertificateIssued(tokenId);
    emit Log("Certificate issued after", tokenId, currentTime, 1);
}

// Assume required state variables and imports are present
mapping(uint256 => uint256) public subscriptionEndTime;
//event SubscriptionExtended(uint256 indexed tokenId, uint256 newExpiration);
// Event Definition (Ensure this is correct in your contract)
event SubscriptionExtended(uint256 indexed tokenId, uint256 extraDays, uint256 newExpiration);

function extendSubscription(uint256 tokenId, uint256 extraDays) external payable {
    require(_exists(tokenId), "Token does not exist");
    require(extraDays > 0, "Must extend by at least 1 day");
    require(ownerOf(tokenId) == msg.sender, "Caller is not the NFT owner");

    // Calculate the required payment
    uint256 dailyRate = 0.1 ether; // Replace with your actual rate
    uint256 paymentRequired = dailyRate * extraDays;
    require(msg.value >= paymentRequired, "Insufficient payment");

    // Determine the new expiration time
    uint256 currentEnd = subscriptionEndTime[tokenId];
    uint256 extensionSeconds = extraDays * 1 days;
    uint256 newEndTime;

    if (block.timestamp < currentEnd) {
        // Subscription is active, extend from current end time
        newEndTime = currentEnd + extensionSeconds;
    } else {
        // Subscription expired or about to expire, start a new period from now
        newEndTime = block.timestamp + extensionSeconds;
    }

    // Update the subscription end time
    subscriptionEndTime[tokenId] = newEndTime;

    // Refund any excess payment
    uint256 excess = msg.value - paymentRequired;
    if (excess > 0) {
        payable(msg.sender).transfer(excess);
    }

    // Emit the event with the correct parameters
    emit SubscriptionExtended(tokenId, extraDays, newEndTime);
}













    // 10. Provide update logs/history for NFTs
    function addNFTLog(uint256 tokenId, string memory logEntry) public onlyOwner {
        nftData.addLog(tokenId, logEntry);
    }

    function getNFTLogs(uint256 tokenId) public view returns (string[] memory) {
        return nftData.getLogs(tokenId);
    }

    // 11. Allow gifting of NFTs to another user
    function giftNFT(uint256 tokenId, address recipient) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        safeTransferFrom(msg.sender, recipient, tokenId);
    }

    // 12. Allow auction-style bidding on NFTs
    // Implementing a full auction system would require additional contracts

    // 13. Integrate oracle for real-time data use
    // Requires additional setup for oracle integration

    // 14. Automatically extend subscription upon payment
// Ensure that the subscription is extended only when a payment is made
// Assuming the event is declared as follows:
//event SubscriptionExtended(uint256 indexed tokenId, uint256 extraDays, uint256 paymentAmount);



// State variable to hold the price per day for subscription extension
uint256 public pricePerDay = 0.1 ether;  // You can modify this later

// Function to allow the owner to update the price per day
function updatePricePerDay(uint256 newPrice) external onlyOwner {
    pricePerDay = newPrice;
}

// Example function to calculate the cost of extending the subscription
function calculatePayment(uint256 extraDays) public view returns (uint256) {
    require(extraDays > 0, "Days must be greater than zero"); // Ensure positive days
    return extraDays * pricePerDay; // Calculate based on dynamic price per day
}
    // 15. Verify document authenticity via hash
    function storeDocumentHash(uint256 tokenId, bytes32 docHash) public onlyOwner {
        nftData.storeDocumentHash(tokenId, docHash);
    }

    function verifyDocument(uint256 tokenId, bytes32 providedHash) public view returns (bool) {
        return nftData.verifyDocumentHash(tokenId, providedHash);
    }

    // 16. Show expiration countdown
    function getNFTExpirationCountdown(uint256 tokenId) public view returns (uint256) {
        return nftData.getExpirationCountdown(tokenId);
    }

    // 17. Enable NFT lending or renting
    function lendNFT(uint256 tokenId, address borrower, uint256 duration) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        nftData.lendNFT(tokenId, borrower, duration);
    }

    function getLendingInfo(uint256 tokenId) public view returns (address borrower, uint256 returnTime) {
        return nftData.getLendingInfo(tokenId);
    }

    // 18. Notify user before NFT expires
    // Notifications are typically off-chain (requires event listeners or external services)

    // 19. Enable batch transfer of NFTs
    function batchTransferNFTs(address to, uint256[] memory tokenIds) public {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "Not the owner");
            safeTransferFrom(msg.sender, to, tokenIds[i]);
        }
    }

    // 20. Add tags or categories to NFTs
    function setNFTTags(uint256 tokenId, string[] memory tags) public onlyOwner {
        nftData.setTags(tokenId, tags);
    }

    function getNFTTags(uint256 tokenId) public view returns (string[] memory) {
        return nftData.getTags(tokenId);
    }

    // 21. Export metadata and transaction history as JSON/CSV
    // Exporting data in JSON/CSV format would typically require off-chain operations


 // Mapping to store URI and Title for each tokenId
    mapping(uint256 => string) private tokenURIs;
    mapping(uint256 => string) private tokenTitles;

    // Function to set metadata for an NFT
    function setNFTMetadata(uint256 tokenId, string memory uri, string memory title) public onlyOwner {
        tokenURIs[tokenId] = uri;
        tokenTitles[tokenId] = title;
    }

    // Function to retrieve metadata for a specific NFT
    function getNFTMetadata(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        // Fetch the URI and Title associated with the NFT
        string memory uri = getURI(tokenId);
        string memory title = getTitle(tokenId);

        // Call the getMetadataJSON function from NFTLib
        return NFTLib.getMetadataJSON(uri, title);
    }

function _exists(uint256 tokenId) internal view override returns (bool) {
    // Check if the token exists and is not expired
    return super._exists(tokenId) && !nftData.expired[tokenId];
}


    // Getter functions for URI and Title
    function getURI(uint256 tokenId) public view returns (string memory) {
        return tokenURIs[tokenId];
    }

    function getTitle(uint256 tokenId) public view returns (string memory) {
        return tokenTitles[tokenId];
    }
// Getter function to check if an address is a whitelisted merchant
function isWhitelistedMerchant(address merchant) public view returns (bool) {
    return whitelistedMerchants[merchant];
}

     // Function to set a log for a specific tokenId
    function setLog(uint256 tokenId, string memory log) external {
        logs[tokenId] = log;
    }


function expireSubscription(uint256 tokenId) external onlyOwner {
    subscriptionEndTime[tokenId] = block.timestamp - 1;
}

    // Set subscription expiration for a token
    function setSubscriptionExpiration(uint256 tokenId, uint256 expirationTime) public onlyOwner {
        subscriptionEndTime[tokenId] = expirationTime;
    }
event SubscriptionEndTimeSet(uint256 tokenId, uint256 endTime);

function setSubscriptionEndTime(uint256 tokenId, uint256 endTime) public {
    require(ownerOf(tokenId) == msg.sender, "Only the owner can set the subscription time");
    subscriptionEndTime[tokenId] = endTime;
    emit SubscriptionEndTimeSet(tokenId, endTime); // Emit event for debugging
}


 

function getOracleData() public view returns (uint256) {
    // Example logic for fetching data from an oracle
    // This could be an external contract call or some mock data
    return 42; // Just an example
}
// Event to emit when a document hash is verified
// Event to log document hash verification attempts
event DocumentHashVerified(uint256 tokenId, bytes32 docHash, bool isVerified);

// View function: returns result without emitting event (suitable for tests/UI)
function isDocumentHashVerified(uint256 tokenId, bytes32 docHash) public view returns (bool) {
    return nftData.documentHashes[tokenId] == docHash;
}

// Action function: emits event, typically used in transactions/logging
function verifyDocumentHash(uint256 tokenId, bytes32 docHash) public {
    bool isVerified = nftData.documentHashes[tokenId] == docHash;
    emit DocumentHashVerified(tokenId, docHash, isVerified);
}

function setDocumentHash(uint256 tokenId, bytes32 docHash) public onlyOwner {
    nftData.documentHashes[tokenId] = docHash;
}


function getExpirationCountdown(uint256 tokenId) public view returns (uint256) {
    return nftData.expiryTimestamps[tokenId] - block.timestamp;
}

// Event to emit when a tag is added
event TagAdded(uint256 tokenId, string tag);

function addTag(uint256 tokenId, string memory tag) public {
    require(_exists(tokenId), "Token does not exist");  // Ensure the token exists
    require(bytes(tag).length > 0, "Tag cannot be empty");
    require(ownerOf(tokenId) == msg.sender, "Only the token owner can add tags");

    nftData.tags[tokenId].push(tag);
    emit TagAdded(tokenId, tag);
}

function exportData(uint256 tokenId) public view returns (string memory) {
    string memory uri = nftData.tokenURIs[tokenId];
    string memory title = nftData.titles[tokenId]; // make sure this exists in your struct

    return string(
        abi.encodePacked(
            '{"tokenId":"',
            Strings.toString(tokenId),
            '", "uri":"',
            uri,
            '", "title":"',
            title,
            '"}'
        )
    );
}


  // Event to emit when a log is added
    event LogUpdated(uint256 indexed tokenId, string logEntry);

    // Function to add a log to a specific tokenId
function addLog(uint256 tokenId, string memory logEntry) public {
    nftData.addLog(tokenId, logEntry);  // Using NFTLib's addLog method
    emit LogUpdated(tokenId, logEntry);
}
 


    // Function to retrieve the logs for a tokenId
    function getUpdateLogs(uint256 tokenId) public view returns (string[] memory) {
        return nftData.getLogs(tokenId);  // Using NFTLib's getLogs method
    }

    // Modifiers
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Only the token owner can perform this action");
        _;
    }

    modifier onlyValidToken(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }
   // Utility function to generate metadata JSON

function getMetadataJSON(uint256 tokenId) public view returns (string memory) {
    string memory uri = tokenURIs[tokenId];
    string memory title = "NFT Title";  // Or dynamically fetch the title
    return string(abi.encodePacked('{"tokenId":"', Strings.toString(tokenId), '", "uri":"', uri, '", "title":"', title, '"}'));
}


function getCountdown(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "Token does not exist");
    uint256 expiration = subscriptionEndTime[tokenId];
    if (block.timestamp >= expiration) {
        return 0;  // Return 0 if the subscription has expired
    }
    return expiration - block.timestamp;
}

function checkForExpiryNotification(uint256 tokenId) public view returns (bool) {
    require(_exists(tokenId), "Token does not exist");
    uint256 expirationTime = subscriptionEndTime[tokenId];
    require(expirationTime > 0, "Subscription end time not set");

    // Check if the subscription is expiring within the next 7 days
    if (expirationTime > block.timestamp && (expirationTime - block.timestamp) <= 7 days) {
        return true;
    }
    return false;
}




function getAuctionStatus(uint256 tokenId) external view returns (bool active, bool ended, uint256 bidEndTime) {
    Auction memory auction = auctions[tokenId];
    return (auction.active, auction.ended, auction.bidEndTime);
}
function getHighestBid(uint256 tokenId) public view returns (Bid memory) {
    Auction storage auction = auctions[tokenId];
    return Bid(auction.highestBidder, auction.highestBid);
}
function getTags(uint256 tokenId) public view returns (string[] memory) {
    require(_exists(tokenId), "Token does not exist");  // Ensure the token exists
    return nftData.tags[tokenId];
}


    // Function to set the staking token
    function setStakingToken(address _stakingToken) external onlyOwner {
        require(_stakingToken != address(0), "Invalid token address");
        stakingToken = IERC20(_stakingToken);
    }

    // Example function to check staked balance (for testing)
    function stakedBalance(address user) external view returns (uint256) {
        return stakingToken.balanceOf(user);
    }
function exists(uint256 tokenId) public view returns (bool) {
    return _exists(tokenId);
}


}

