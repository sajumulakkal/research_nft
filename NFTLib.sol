// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";

library NFTLib {
    struct Feedback {
        address user;
        uint8 rating;
        string comment;
        uint256 timestamp;
    }

    struct Comment {
        address user;
        string content;
        uint256 timestamp;
    }

    struct SaleInfo {
        bool listed;
        uint256 price;
    }

    struct Lending {
        address borrower;
        uint256 returnTime;
    }

    struct Data {
        mapping(uint256 => Feedback[]) feedbacks;
        mapping(uint256 => uint256) ratingSum;
        mapping(uint256 => uint256) ratingCount;
        mapping(uint256 => Comment[]) comments;

        // Added
        mapping(uint256 => SaleInfo) saleListings;
        mapping(uint256 => bool) activeNFTs;
        mapping(address => bool) bannedUsers;
        mapping(uint256 => string[]) updateLogs;
        mapping(uint256 => bool) expired;
        mapping(uint256 => uint256) expiryTimestamps;
        mapping(uint256 => Lending) lendingData;
        mapping(uint256 => string[]) tags;
        mapping(uint256 => bytes32) documentHashes;
        mapping(uint256 => string) tokenURIs; 
        mapping(uint256 => string) titles;
        
    }

    event FeedbackSubmitted(uint256 indexed tokenId, address indexed user, uint8 rating, string comment, uint256 timestamp);
    event CommentAdded(uint256 indexed tokenId, address indexed user, string content, uint256 timestamp);

    // Feedback
    function addFeedback(Data storage self, uint256 tokenId, address user, uint8 rating, string memory comment) internal {
        require(rating > 0 && rating <= 5, "Rating must be between 1 and 5");

        self.feedbacks[tokenId].push(Feedback({
            user: user,
            rating: rating,
            comment: comment,
            timestamp: block.timestamp
        }));

        self.ratingSum[tokenId] += rating;
        self.ratingCount[tokenId]++;

        emit FeedbackSubmitted(tokenId, user, rating, comment, block.timestamp);
    }

    function getFeedback(Data storage self, uint256 tokenId) internal view returns (Feedback[] memory) {
        return self.feedbacks[tokenId];
    }

    function getAverageRating(Data storage self, uint256 tokenId) internal view returns (uint256) {
        if (self.ratingCount[tokenId] == 0) return 0;
        return self.ratingSum[tokenId] / self.ratingCount[tokenId];
    }

    // Comments
    function addComment(Data storage self, uint256 tokenId, address user, string memory content) internal {
        self.comments[tokenId].push(Comment({
            user: user,
            content: content,
            timestamp: block.timestamp
        }));
        emit CommentAdded(tokenId, user, content, block.timestamp);
    }

    function getComments(Data storage self, uint256 tokenId) internal view returns (Comment[] memory) {
        return self.comments[tokenId];
    }

    // Marketplace
    function listNFT(Data storage self, uint256 tokenId, uint256 price) internal {
        self.saleListings[tokenId] = SaleInfo(true, price);
    }

    function delistNFT(Data storage self, uint256 tokenId) internal {
        delete self.saleListings[tokenId];
    }

    function updateSalePrice(Data storage self, uint256 tokenId, uint256 newPrice) internal {
        require(self.saleListings[tokenId].listed, "NFT not listed");
        self.saleListings[tokenId].price = newPrice;
    }

    function getSaleInfo(Data storage self, uint256 tokenId) internal view returns (bool listed, uint256 price) {
        SaleInfo memory info = self.saleListings[tokenId];
        return (info.listed, info.price);
    }

    // Active NFTs
    function getActiveNFTs(Data storage self, uint256[] memory allNFTs) internal view returns (uint256[] memory) {
        uint count;
        for (uint i = 0; i < allNFTs.length; i++) {
            if (self.activeNFTs[allNFTs[i]]) count++;
        }
        uint256[] memory result = new uint256[](count);
        uint index;
        for (uint i = 0; i < allNFTs.length; i++) {
            if (self.activeNFTs[allNFTs[i]]) result[index++] = allNFTs[i];
        }
        return result;
    }

    // Ban user
    function banUser(Data storage self, address user) internal {
        self.bannedUsers[user] = true;
    }

    function isUserBanned(Data storage self, address user) internal view returns (bool) {
        return self.bannedUsers[user];
    }

    // Certificate
    function issueCertificate(Data storage self, uint256 tokenId) internal view returns (string memory) {
        require(self.expired[tokenId], "NFT not expired");
        return string(abi.encodePacked("Certificate for TokenID: ", Strings.toString(tokenId)));
    }


    // Subscription
    //function extendSubscription(Data storage self, uint256 tokenId, uint256 extraDays) internal {
      //  self.expiryTimestamps[tokenId] += extraDays * 1 days;
    //}

function extendSubscription(Data storage self, uint256 tokenId, uint256 extraDays, uint256 currentTimestamp) internal {
    // If the subscription has expired, start from the current time
    if (self.expiryTimestamps[tokenId] < currentTimestamp) {
        self.expiryTimestamps[tokenId] = currentTimestamp + (extraDays * 1 days);
    } else {
        // Otherwise, just add the extra days
        self.expiryTimestamps[tokenId] += extraDays * 1 days;
    }
}


    function isExpiringSoon(Data storage self, uint256 tokenId) internal view returns (bool) {
        return self.expiryTimestamps[tokenId] > 0 && self.expiryTimestamps[tokenId] - block.timestamp < 2 days;
    }

    function getExpirationCountdown(Data storage self, uint256 tokenId) internal view returns (uint256) {
        return block.timestamp >= self.expiryTimestamps[tokenId] ? 0 : self.expiryTimestamps[tokenId] - block.timestamp;
    }

    // Lending
    function lendNFT(Data storage self, uint256 tokenId, address borrower, uint256 duration) internal {
        self.lendingData[tokenId] = Lending(borrower, block.timestamp + duration);
    }

    function getLendingInfo(Data storage self, uint256 tokenId) internal view returns (address, uint256) {
        Lending memory info = self.lendingData[tokenId];
        return (info.borrower, info.returnTime);
    }

    // Tags
    function setTags(Data storage self, uint256 tokenId, string[] memory tags) internal {
        self.tags[tokenId] = tags;
    }

    function getTags(Data storage self, uint256 tokenId) internal view returns (string[] memory) {
        return self.tags[tokenId];
    }

    // Doc authenticity
    function storeDocumentHash(Data storage self, uint256 tokenId, bytes32 docHash) internal {
        self.documentHashes[tokenId] = docHash;
    }

    function verifyDocumentHash(Data storage self, uint256 tokenId, bytes32 providedHash) internal view returns (bool) {
        return self.documentHashes[tokenId] == providedHash;
    }

    // Metadata
    function getMetadataJSON(string memory uri, string memory title) internal pure returns (string memory) {
        return string(abi.encodePacked('{"uri":"', uri, '", "title":"', title, '"}'));
    }
function distributeReward(Data storage self, uint256 tokenId, address recipient, uint256 amount) internal {
    self.feedbacks[tokenId].push(Feedback(recipient, uint8(amount), "Rewarded", block.timestamp));
}
    // Function to add a log for a specific tokenId
    function addLog(Data storage self, uint256 tokenId, string memory logEntry) internal {
        self.updateLogs[tokenId].push(logEntry);
    }

    // Function to get logs for a specific tokenId
    function getLogs(Data storage self, uint256 tokenId) internal view returns (string[] memory) {
        return self.updateLogs[tokenId];
    }
}
