const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseUnits } = require('ethers');
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { keccak256, toUtf8Bytes } = require("ethers");

describe("ResearchNFT Contract", function () {
  let ResearchNFT, researchNFT, owner, addr1, addr2, addr3, merchant;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3,merchant] = await ethers.getSigners();
    ResearchNFT = await ethers.getContractFactory("ResearchNFT");
    researchNFT = await ResearchNFT.deploy();

        // Set document hash for tokenId 1 manually (simulate expected value)
        const document = "This is a document content";
        const docHash = keccak256(toUtf8Bytes(document));

        // You'll need a function in the contract like setDocumentHash(tokenId, docHash) for this to work:
        await researchNFT.connect(owner).setDocumentHash(1, docHash); // Assumes only owner can set it
  });



  /** 1. DEPLOYMENT & MINTING **/
  it("Should deploy with correct name and symbol", async function () {
    expect(await researchNFT.name()).to.equal("ResearchNFT");
    expect(await researchNFT.symbol()).to.equal("RNFT");
  });

  it("Should mint an NFT", async function () {
    await researchNFT.createResearchNFT("ipfs://metadata1", "ipfs://doc1", 500, 100000, 1);
    expect(await researchNFT.tokenURI(0)).to.equal("ipfs://metadata1");
  });

  /** 2. METADATA & DOCUMENT UPDATES **/
  it("Should update metadata and document URI", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await researchNFT.updateMetadataURI(0, "ipfs://meta2");
    await researchNFT.updateDocumentURI(0, "ipfs://doc2");
    expect(await researchNFT.tokenURI(0)).to.equal("ipfs://meta2");
  });

  /** 3. AUCTION & BIDDING **/
  it("Should start an auction, allow bidding, and end auction", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);

    await researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("1.5") });
    await researchNFT.connect(addr2).placeBid(0, { value: ethers.parseEther("2") });

    await ethers.provider.send("evm_increaseTime", [3600]);
    await ethers.provider.send("evm_mine");

    await researchNFT.endAuction(0);

    const auctionData = await researchNFT.auctions(0);
    expect(auctionData.active).to.equal(false);
    expect(auctionData.highestBidder).to.equal(addr2.address);
    expect(auctionData.highestBid).to.equal(ethers.parseEther("2"));

    const newOwner = await researchNFT.ownerOf(0);
    expect(newOwner).to.equal(addr2.address);
  });

  /** 4. VIEW COUNT TRACKING **/
  it("Should increment view count", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await researchNFT.incrementViewCount(0);
    const data = await researchNFT.researchData(0);
    expect(data.views).to.equal(1);
  });

  /** 5. ACCESS CONTROL **/
  it("Should pause and unpause the contract", async function () {
    await researchNFT.pause();
    await expect(
      researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1)
    ).to.be.revertedWith("Pausable: paused");

    await researchNFT.unpause();
    await expect(
      researchNFT.createResearchNFT("ipfs://meta2", "ipfs://doc2", 500, 100000, 1)
    ).to.not.be.reverted;
  });

/** 6. ROYALTIES & PAYOUTS **/
it("Should allow NFT purchase", async function () {
  await researchNFT.connect(owner).createResearchNFT("ipfs://meta2", "ipfs://doc2", 500, 100000, 1);
  await researchNFT.connect(owner).setForSale(0, ethers.parseEther("1"));

  // Get seller balance before purchase as BigInt
  const balanceBefore = await ethers.provider.getBalance(owner.address);
  const balanceBeforeBN = BigInt(balanceBefore.toString());

  // Perform purchase
  const tx = await researchNFT.connect(addr1).buyNFT(0, { value: ethers.parseEther("1") });
  await tx.wait();

  const balanceAfter = await ethers.provider.getBalance(owner.address);
  const balanceAfterBN = BigInt(balanceAfter.toString());

  // Calculate amount received
  const diff = balanceAfterBN - balanceBeforeBN;

  // Expect seller received something
  expect(diff > 0n).to.be.true;

  // Ensure ownership transferred
  expect(await researchNFT.ownerOf(0)).to.equal(addr1.address);
});




  /** 7. NFT EXPIRATION **/
  it("Should check NFT expiration status", async function () {
    const now = Math.floor(Date.now() / 1000);
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, now - 1, 1);
    expect(await researchNFT.isExpired(0)).to.equal(true);
  });

  /** 8. OWNERSHIP TRANSFER **/
  it("Should transfer ownership of NFT", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await researchNFT.transferFrom(owner.address, addr1.address, 0);
    expect(await researchNFT.ownerOf(0)).to.equal(addr1.address);
  });

  /** 9. PERMISSIONS & RESTRICTED ACCESS **/
  it("Should restrict non-owners from updating metadata", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await expect(
      researchNFT.connect(addr1).updateMetadataURI(0, "ipfs://meta2")
    ).to.be.revertedWith("Not NFT owner");
  });

  /** 10. BURNING NFT **/
  it("Should burn an NFT", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await researchNFT.burn(0);
    await expect(researchNFT.tokenURI(0)).to.be.revertedWith("ERC721: invalid token ID");
  });

/** 11. SETTING ROYALTIES **/
it("Should set royalties correctly", async function () {
    // Create NFT with some metadata and set royalty details
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);

    // Set royalties to 5% (500 basis points)
    await researchNFT.setRoyalties(0, 500);

    // Fetch royalty info for token ID 0 and a sale price of 1 ether
    const royaltyInfo = await researchNFT.royaltyInfo(0, ethers.parseEther("1"));

    // Verify that the receiver of the royalties is the contract owner
    expect(royaltyInfo.receiver).to.equal(owner.address);

    // Verify that the royalty amount is 5% of 1 ether (which is 0.05 ether = 5000000000000000 wei)
    expect(royaltyInfo.royaltyAmount).to.equal(ethers.parseEther("0.05"));
});


  /** 12. AUCTION EXTENSION **/
  it("Should extend auction on new bid", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);
    await researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("1.5") });

    const auction = await researchNFT.auctions(0);
    const now = Math.floor(Date.now() / 1000);
    expect(Number(auction.bidEndTime)).to.be.gt(now + 3600);
  });

/** 13. DIRECT SALE **/
it("Should allow NFT purchase", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
    await researchNFT.setForSale(0, ethers.parseEther("1"));

    const balanceBefore = await ethers.provider.getBalance(owner.address);
    await researchNFT.connect(addr1).buyNFT(0, { value: ethers.parseEther("1") });
    const balanceAfter = await ethers.provider.getBalance(owner.address);

    // Convert balances to BigInt and subtract
    const balanceDiff = BigInt(balanceAfter.toString()) - BigInt(balanceBefore.toString());

    // Check if the balance difference is equal to 1 ETH
    expect(balanceDiff).to.equal(BigInt(ethers.parseEther("1").toString()));

    // Check that the NFT ownership has transferred to addr1
    expect(await researchNFT.ownerOf(0)).to.equal(addr1.address);
});

/** 14. CHECKING NFT SALE STATUS **/
it("Should allow checking if NFT is for sale", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
  await researchNFT.setForSale(0, ethers.parseEther("2"));
  const forSale = await researchNFT.isForSale(0);
  expect(forSale).to.equal(true);
});

/** 15A. RESTRICTED AUCTION FUNCTIONALITY **/
it("Should not allow non-owners to start auction", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);

  await expect(
    researchNFT.connect(addr1).startAuction(0, ethers.parseEther("1"), 3600)
  ).to.be.revertedWith("Not NFT owner"); // <-- fix here
});


/** 15B. RESTRICTED AUCTION FUNCTIONALITY **/

it("Should allow the NFT owner (not contract owner) to start auction", async function () {
  // Let addr1 create and own an NFT
  await researchNFT.connect(addr1).createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);

  // addr1 starts an auction on their NFT (should succeed)
  await expect(
    researchNFT.connect(addr1).startAuction(0, ethers.parseEther("1"), 3600)
  ).to.not.be.reverted;

  // Confirm auction is active
  const auction = await researchNFT.auctions(0);
  expect(auction.active).to.equal(true);
  expect(auction.highestBid).to.equal(ethers.parseEther("1"));
});

/** 16. RESTRICTED PURCHASE FUNCTIONALITY **/
it("Should not allow purchase if not for sale", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
  await expect(
    researchNFT.connect(addr1).buyNFT(0, { value: ethers.parseEther("1") })
  ).to.be.revertedWith("NFT not for sale"); // <-- fixed string
});


/** 17. RESTRICTED BIDDING FUNCTIONALITY **/
it("Should not allow bidding on non-auction NFTs", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
  await expect(
    researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("1.5") })
  ).to.be.revertedWith("Auction not active"); // <-- Correct string
});


/** 18. VERIFYING THE NFT AUCTION FINALIZATION **/
it("Should finalize auction correctly when ending", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
  await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);

  // First bid from addr1
  await researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("1.5") });

  // Second bid from addr2
  await researchNFT.connect(addr2).placeBid(0, { value: ethers.parseEther("2") });

  // Simulate time progression and end the auction
  await ethers.provider.send("evm_increaseTime", [3600]);
  await ethers.provider.send("evm_mine");

  await researchNFT.endAuction(0);

  const auctionData = await researchNFT.auctions(0);
  expect(auctionData.active).to.equal(false); // Auction should be inactive after ending
  expect(auctionData.highestBidder).to.equal(addr2.address); // addr2 should be the highest bidder
  expect(auctionData.highestBid).to.equal(ethers.parseEther("2")); // Highest bid should be 2 ETH

  // Ownership should be transferred to the highest bidder
  const newOwner = await researchNFT.ownerOf(0);
  expect(newOwner).to.equal(addr2.address);
});

/** 19.Check Auction Time Extension on New Bid **/
it("Should extend auction duration with a new bid", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
  await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);

  // Initial bid by addr1
  await researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("1.5") });

  // Capture the auction end time before placing a new bid
  const auctionBefore = await researchNFT.auctions(0);

  // Place a new bid from addr2
  await researchNFT.connect(addr2).placeBid(0, { value: ethers.parseEther("2") });

  // Capture the auction end time after placing the new bid
  const auctionAfter = await researchNFT.auctions(0);

  // Check that the auction end time has increased (extended) after the new bid
  expect(auctionAfter.bidEndTime).to.be.gt(auctionBefore.bidEndTime);
});

/** 20. Check if NFT is Not Re-Saleable after Auction End **/
it("Should not allow re-sale of NFT after auction", async function () {
  // Step 1: Mint a new NFT
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);

  // Step 2: Start an auction as the owner
  await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);

  // Step 3: Place a bid from addr1
  await researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("2") });

  // Step 4: Fast-forward time to simulate auction end
  await ethers.provider.send("evm_increaseTime", [3600]);
  await ethers.provider.send("evm_mine");

  // Step 5: End the auction
  await researchNFT.endAuction(0);

  // Step 6: Confirm ownership transferred to addr1 (highest bidder)
  const newOwner = await researchNFT.ownerOf(0);
  expect(newOwner).to.equal(addr1.address);

  // Step 7: Check if the NFT is for sale (should be false)
  const forSale = await researchNFT.isForSale(0);
  expect(forSale).to.equal(false);

  // Step 8: Try to set the NFT for sale again (should fail with proper reason)
  await expect(
    researchNFT.connect(addr1).setForSale(0, ethers.parseEther("1"))
  ).to.be.revertedWith("NFT already sold at auction");
});


/** 21.  Test for Non-Owner Changing Royalties **/
it("Should restrict non-owners from setting royalties", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);

  // Non-owner tries to set royalties (should fail)
  await expect(
    researchNFT.connect(addr1).setRoyalties(0, 500)
  ).to.be.revertedWith("Only the owner can set royalties");

  // Owner can set royalties
  await expect(
    researchNFT.connect(owner).setRoyalties(0, 500)
  ).to.not.be.reverted;
});


/** 22. Test for NFT Transfer during Auction **/
it("Should not allow NFT transfer during auction", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);
  await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);

  // Try transferring NFT while auction is active (should fail)
  await expect(
    researchNFT.transferFrom(owner.address, addr1.address, 0)
  ).to.be.revertedWith("Cannot transfer during auction");

  // End auction and transfer NFT (should succeed)
  await ethers.provider.send("evm_increaseTime", [3600]);
  await ethers.provider.send("evm_mine");
  await researchNFT.endAuction(0);

  await researchNFT.transferFrom(owner.address, addr1.address, 0);
  expect(await researchNFT.ownerOf(0)).to.equal(addr1.address);
});
/** 23. Test for Multiple Auctions of the Same NFT **/
it("Should not allow multiple auctions for the same NFT", async function () {
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);

  // Start the first auction
  await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);

  // Try starting another auction for the same NFT (should fail)
  await expect(
    researchNFT.startAuction(0, ethers.parseEther("2"), 3600)
  ).to.be.revertedWith("Auction already active"); // Update to match the current error message
});


/** 24. Test for Correct Royalties during Sale **/
it("Should pay royalties during NFT sale", async function () {
  const [owner, addr1, royaltyRecipient] = await ethers.getSigners();

  // Deploy contract
  const ResearchNFT = await ethers.getContractFactory("ResearchNFT");
  const researchNFT = await ResearchNFT.deploy();

  // Mint NFT to royaltyRecipient
  await researchNFT.connect(royaltyRecipient).createResearchNFT("ipfs://meta1", "ipfs://doc1", 0, 100000, 1);

  // royaltyRecipient sets royalties (they are the owner of tokenId 0)
  await researchNFT.connect(royaltyRecipient).setRoyalties(0, 500); // 5%

  // Transfer NFT to `owner` (now seller is `owner`, royalty goes to `royaltyRecipient`)
  await researchNFT.connect(royaltyRecipient).transferFrom(royaltyRecipient.address, owner.address, 0);

  // Set for sale
  const salePrice = ethers.parseEther("1.0");
  await researchNFT.connect(owner).setForSale(0, salePrice);

  // Track balances
  const initialOwnerBalance = await ethers.provider.getBalance(owner.address);
  const initialRoyaltyBalance = await ethers.provider.getBalance(royaltyRecipient.address);

  // Buyer purchases NFT
  const tx = await researchNFT.connect(addr1).buyNFT(0, { value: salePrice });
  await tx.wait();

  const finalOwnerBalance = await ethers.provider.getBalance(owner.address);
  const finalRoyaltyBalance = await ethers.provider.getBalance(royaltyRecipient.address);

  const ownerDiff = finalOwnerBalance - initialOwnerBalance;
  const royaltyDiff = finalRoyaltyBalance - initialRoyaltyBalance;

  console.log("Owner received:", ethers.formatEther(ownerDiff));
  console.log("Royalty received:", ethers.formatEther(royaltyDiff));

  // Check expected values
  const expectedRoyalty = salePrice * 500n / 10000n;
  const expectedOwner = salePrice - expectedRoyalty;
  const tolerance = ethers.parseEther("0.01");

  expect(ownerDiff).to.be.closeTo(expectedOwner, tolerance);
  expect(royaltyDiff).to.be.closeTo(expectedRoyalty, tolerance);
});

/** 25. Test for Access Control on pause and unpause **/
it("Should restrict pausing/unpausing to the owner", async function () {
  await expect(
    researchNFT.connect(addr1).pause()
  ).to.be.revertedWith("Ownable: caller is not the owner");

  await expect(
    researchNFT.connect(addr1).unpause()
  ).to.be.revertedWith("Ownable: caller is not the owner");

  // Owner can pause and unpause
  await expect(
    researchNFT.connect(owner).pause()
  ).to.not.be.reverted;
  
  await expect(
    researchNFT.connect(owner).unpause()
  ).to.not.be.reverted;
});

/** 26. Test for Access Control on pause and unpause **/
it("Should not allow actions when the contract is paused", async function () {
  // Mint a token first (ID 0 will be created here)
  await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 100000, 1);

  // Pause the contract
  await researchNFT.pause();
  
  // Verify the paused state of the contract (Optional Debugging)
  const pausedState = await researchNFT.paused();
  console.log("Contract paused state:", pausedState);  // Should log true

  // Ensure that minting is blocked when paused
  await expect(
    researchNFT.createResearchNFT("ipfs://meta2", "ipfs://doc2", 500, 100000, 1)
  ).to.be.revertedWith("Pausable: paused");

  // Ensure that starting an auction is blocked when paused
  await expect(
    researchNFT.startAuction(0, ethers.parseEther("1"), 3600)
  ).to.be.revertedWith("Pausable: paused");

  // Unpause the contract before proceeding further
  await researchNFT.unpause();

  // Verify the paused state after unpausing (Optional Debugging)
  const unpausedState = await researchNFT.paused();
  console.log("Contract unpaused state:", unpausedState);  // Should log false

  // Now start an auction for the minted NFT (ID 0)
  await expect(
    researchNFT.startAuction(0, ethers.parseEther("2"), 3600)
  ).to.not.be.reverted;

  // Mint another NFT after unpausing the contract
  await researchNFT.createResearchNFT("ipfs://meta2", "ipfs://doc2", 500, 100000, 1);

  // Now, start an auction for the newly minted NFT (ID 1)
  await expect(
    researchNFT.startAuction(1, ethers.parseEther("3"), 360)
  ).to.not.be.reverted;
});



 /** 
   * 27. Multi-Signature Approvals:
   * Test adding research owners and require majority approval for executing an action.
   */
it("Should add new research owners and emit the event", async function () {
    const [owner, addr1] = await ethers.getSigners();

    const ResearchNFT = await ethers.getContractFactory("ResearchNFT");
    const researchNFT = await ResearchNFT.connect(owner).deploy();
    await researchNFT.waitForDeployment(); // For Ethers v6+

    const newOwner = addr1.address;

    // ✅ Call the function from the deployer (owner)
    const tx = await researchNFT.connect(owner).addResearchOwner(newOwner);
    const receipt = await tx.wait();

    // ✅ Debug output (optional)
    console.log("Emitted events:", receipt.logs.map(log => log.fragment?.name));

    // ✅ Check event
    const event = receipt.logs.find(e => e.fragment.name === "NewResearchOwner");
    expect(event).to.not.be.undefined;
    expect(event.args.newOwner).to.equal(newOwner);

    // ✅ Check internal state
    const isOwner = await researchNFT.isResearchOwner(newOwner);
    expect(isOwner).to.be.true;
});



  /** 
   * 28. Bundling NFTs:
   * Test that multiple NFTs can be bundled into a single NFT and the bundle mapping is set correctly.
   */
// Assuming you are using Ethers v6
// Fix the test: Should bundle multiple NFTs into one bundle NFT

it("Should bundle multiple NFTs into one bundle NFT", async function () {
    const [owner] = await ethers.getSigners();

    // Deploy the contract and connect to owner
    const ResearchNFT = await ethers.getContractFactory("ResearchNFT");
    const researchNFT = await ResearchNFT.deploy();
    await researchNFT.waitForDeployment();

    // Mint two research NFTs (assumes only owner can mint)
    await researchNFT.connect(owner).createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 200000, 1);
    await researchNFT.connect(owner).createResearchNFT("ipfs://meta2", "ipfs://doc2", 500, 200000, 1);

    // Bundle them (expect event emission)
    await expect(researchNFT.connect(owner).bundleNFTs([0, 1]))
        .to.emit(researchNFT, "NFTsBundled");

    // Fetch bundled token IDs
    const bundledTokens = await researchNFT.getBundle(2); // Assuming getBundle is a public view function

    expect(bundledTokens.length).to.equal(2);
    expect(bundledTokens[0]).to.equal(0);
    expect(bundledTokens[1]).to.equal(1);
});
  /** 
   * 29. Revoking Access:
   * Test that calling revokeAccess burns an NFT.
   */
  it("Should revoke access by burning an NFT", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 200000, 1);
    await researchNFT.revokeAccess(0);
    await expect(researchNFT.tokenURI(0)).to.be.revertedWith("ERC721: invalid token ID");
  });

  /** 
   * 30. Authenticity Verification:
   * Test that calling verifyAuthenticity emits the ContentVerified event.
   */
  it("Should emit ContentVerified event when verifying authenticity", async function () {
    await expect(researchNFT.verifyAuthenticity(0, true))
      .to.emit(researchNFT, "ContentVerified")
      .withArgs(0, true);
  });

  /** 
   * 31. Translation Functionality:
   * Test that translations can be set and retrieved.
   */
  it("Should set and retrieve NFT translation", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 200000, 1);
    await researchNFT.setTranslation(0, "fr", "Contenu traduit");
    const translation = await researchNFT.getTranslation(0, "fr");
    expect(translation).to.equal("Contenu traduit");
  });

  /** 
   * 32. Subscription Management:
   * Test upgrading and downgrading a subscription by adjusting access level.
   */
  it("Should upgrade and downgrade subscription access level", async function () {
    // Mint an NFT.
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 200000, 1);

    // Upgrade subscription: set access level to 2.
    await researchNFT.upgradeSubscription(0, 2);
    let level = await researchNFT.getUserAccessLevel(0, owner.address);
    expect(level).to.equal(2);

    // Downgrade subscription: revert access level to 1.
    await researchNFT.downgradeSubscription(0, 1);
    level = await researchNFT.getUserAccessLevel(0, owner.address);
    expect(level).to.equal(1);
  });

  /** 
   * 33. Sharing Access:
   * Test that sharing access mints a new NFT and emits an AccessShared event.
   */
  it("Should share access via minting a new NFT", async function () {
    await researchNFT.createResearchNFT("ipfs://meta1", "ipfs://doc1", 500, 200000, 1);
    await expect(researchNFT.shareAccess(0, addr1.address))
      .to.emit(researchNFT, "AccessShared")
      .withArgs(0, addr1.address);
  });

  /** 
   * 34. Engagement Tracking:
   * Test that trackEngagement emits the UserEngaged event.
   */
  it("Should emit UserEngaged event on engagement tracking", async function () {
    await expect(researchNFT.trackEngagement(addr1.address, 0, "view"))
      .to.emit(researchNFT, "UserEngaged")
      .withArgs(addr1.address, 0, "view");
  });

  /** 
   * 35. Content Preview:
   * Test that a preview URL can be set and retrieved.
   */
  it("Should set and retrieve content preview URL", async function () {
    await researchNFT.setPreview(0, "ipfs://preview1");
    const preview = await researchNFT.getPreview(0);
    expect(preview).to.equal("ipfs://preview1");
  });

  /** 
   * 36. User Access Level:
   * Test setting and retrieving a user's access level for a given NFT.
   */
  it("Should set and get user access level", async function () {
    await researchNFT.setUserAccessLevel(0, addr1.address, 3);
    const level = await researchNFT.getUserAccessLevel(0, addr1.address);
    expect(level).to.equal(3);
  });

  /** 
   * 37. Contract Ownership Transfer:
   * Test that ownership of the contract can be transferred.
   */
  it("Should transfer contract ownership", async function () {
    await researchNFT.transferOwnershipOfContract(addr2.address);
    expect(await researchNFT.owner()).to.equal(addr2.address);
  });
/* Failing Bids */
it("Should reject bids lower than current highest", async function () {
  await researchNFT.createResearchNFT("ipfs://meta", "ipfs://doc", 500, 100000, 1);
  await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);
  await researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("2") });

  await expect(
    researchNFT.connect(addr2).placeBid(0, { value: ethers.parseEther("1.5") })
  ).to.be.revertedWith("Bid too low");
});

/*Unauthorized Auction End  */
it("Should prevent non-owner from ending the auction", async function () {
  await researchNFT.createResearchNFT("ipfs://meta", "ipfs://doc", 500, 100000, 1);
  await researchNFT.startAuction(0, ethers.parseEther("1"), 3600);

  // Fast forward time
  await ethers.provider.send("evm_increaseTime", [3600]);
  await ethers.provider.send("evm_mine");

  // Now try to end auction with non-owner
  await expect(
    researchNFT.connect(addr1).endAuction(0)
  ).to.be.revertedWith("Not NFT owner");
});


/* Cannot Place Bid After Auction Ends */
it("Should prevent bidding after auction ends", async function () {
  await researchNFT.createResearchNFT("ipfs://meta", "ipfs://doc", 500, 100000, 1);
  await researchNFT.startAuction(0, ethers.parseEther("1"), 1);

  await ethers.provider.send("evm_increaseTime", [2]);
  await ethers.provider.send("evm_mine");

  await researchNFT.endAuction(0);

  await expect(
    researchNFT.connect(addr1).placeBid(0, { value: ethers.parseEther("2") })
  ).to.be.revertedWith("Auction not active");
});
/* Royalty Info for Nonexistent Token */
it("Should revert royalty info request for non-existent token", async function () {
  await expect(
    researchNFT.royaltyInfo(999, ethers.parseEther("1"))
  ).to.be.revertedWith("ERC721: invalid token ID");
});

/* Purchase of NFT Not For Sale */
it("Should prevent buying an NFT not set for sale", async function () {
  await researchNFT.createResearchNFT("ipfs://meta", "ipfs://doc", 500, 100000, 1);
  await expect(
    researchNFT.connect(addr1).buyNFT(0, { value: ethers.parseEther("1") })
  ).to.be.revertedWith("NFT not for sale");
});

/*. Document URI Retrieval */
 it("Should retrieve the correct document URI", async function () {
  await researchNFT.createResearchNFT("ipfs://meta", "ipfs://doc", 500, 100000, 1);
  const data = await researchNFT.researchData(0);
  expect(data.documentURI).to.equal("ipfs://doc");
});


  it("Should increment readership count and emit event when research is viewed", async function () {
    // Mint an NFT
    await researchNFT.createResearchNFT("ipfs://meta", "ipfs://doc", 500, 100000, 1);
    
    // View the research
    const tx = await researchNFT.connect(addr1).viewResearch(0);

    // Check the readership count
    const count = await researchNFT.getReadershipCount(0);
    expect(count).to.equal(1);

    // Check that event was emitted correctly
    await expect(tx)
      .to.emit(researchNFT, "ResearchViewed")
      .withArgs(0, addr1.address, 1);
  });

  it("Should correctly increment multiple views", async function () {
    await researchNFT.createResearchNFT("ipfs://meta", "ipfs://doc", 500, 100000, 1);
    
    await researchNFT.connect(addr1).viewResearch(0);
    await researchNFT.connect(addr2).viewResearch(0);
    await researchNFT.connect(addr1).viewResearch(0);

    const count = await researchNFT.getReadershipCount(0);
    expect(count).to.equal(3);
  });

  it("Should revert when viewing nonexistent research", async function () {
    await expect(researchNFT.viewResearch(999))
      .to.be.revertedWith("ResearchNFT: View query for nonexistent token");
  });

  it("Should revert when getting readership count for nonexistent research", async function () {
    await expect(researchNFT.getReadershipCount(999))
      .to.be.revertedWith("ResearchNFT: Count query for nonexistent token");
  });


it("should allow a user to add feedback", async function () {
  const tokenId = 1;
  const rating = 5;
  const comment = "Excellent research paper.";

  // Assuming the token with tokenId 1 exists or mint it if necessary
  // await researchNFT.mint(addr1.address, tokenId);

  await researchNFT.connect(addr1).addFeedback(tokenId, addr1.address, rating, comment);

  const feedbacks = await researchNFT.getFeedback(tokenId);
  expect(feedbacks.length).to.equal(1);
  expect(feedbacks[0].user).to.equal(addr1.address);
  expect(feedbacks[0].rating).to.equal(rating);
  expect(feedbacks[0].comment).to.equal(comment);
});

it("should retrieve all feedback for a token", async function () {
  const tokenId = 1;

  await researchNFT.connect(addr1).addFeedback(tokenId, addr1.address, 4, "Good work.");
  await researchNFT.connect(addr2).addFeedback(tokenId, addr2.address, 5, "Outstanding!");

  const feedbacks = await researchNFT.getFeedback(tokenId);
  expect(feedbacks.length).to.equal(2);
  expect(feedbacks[0].user).to.equal(addr1.address);
  expect(feedbacks[1].user).to.equal(addr2.address);
});

it("should calculate the average rating correctly", async function () {
  const tokenId = 1;

  await researchNFT.connect(addr1).addFeedback(tokenId, addr1.address, 3, "Average.");
  await researchNFT.connect(addr2).addFeedback(tokenId, addr2.address, 5, "Excellent!");

  const averageRating = await researchNFT.getAverageRating(tokenId);
  expect(averageRating).to.equal(4); // (3 + 5) / 2
});
it("Should allow users to add comments", async function () {
    // Whitelist addr1 as a merchant before minting
    await researchNFT.connect(owner).addMerchant(addr1.address);

    // Mint the NFT
    const tx = await researchNFT.connect(addr1).mintRewardNFT(
        addr2.address,
        addr3.address,
        "metadataURI"
    );

    // Wait for the transaction to be mined
    const receipt = await tx.wait();

    // Parse logs to find the RewardMinted event
    const iface = researchNFT.interface;
    let tokenId;
    for (const log of receipt.logs) {
        try {
            const parsedLog = iface.parseLog(log);
            if (parsedLog.name === "RewardMinted") {
                tokenId = parsedLog.args.tokenId.toString();
                break;
            }
        } catch (e) {
            // Ignore logs that do not belong to the contract
        }
    }

    expect(tokenId, "RewardMinted event not emitted").to.not.be.undefined;

    // Add comment to the NFT
    await researchNFT.connect(addr1).addComment(tokenId, "This is a great piece of research!");

    // Fetch and check comment
    const comments = await researchNFT.getComments(tokenId);
    expect(comments.length).to.equal(1);
    expect(comments[0].content).to.equal("This is a great piece of research!");
});


it("Should emit CommentAdded event upon adding a comment", async function () {
  // 1) Mint the NFT so tokenId 0 exists
  await researchNFT.connect(owner).createResearchNFT(
    "ipfs://meta",
    "ipfs://doc",
    500,
    Math.floor(Date.now()/1e3) + 3600,
    1
  );

  // 2) Add a comment to tokenId 0
  await expect(
    researchNFT.connect(addr1).addComment(0, "Insightful work!")
  )
    .to.emit(researchNFT, "CommentAdded")
    .withArgs(0, addr1.address, "Insightful work!", anyValue); // anyValue skips exact timestamp :contentReference[oaicite:1]{index=1}
});

it("1. Vote to promote quality research", async function () {
    const [merchant, vendor, employee] = await ethers.getSigners();

    // Whitelist the merchant
    await researchNFT.connect(merchant).addMerchant(merchant.address); // assuming addMerchant exists

    // Mint the NFT to the employee
    const metadataURI = "ipfs://sample-research";
    await researchNFT.connect(merchant).mintRewardNFT(
        vendor.address,
        employee.address,
        metadataURI
    );

    const tokenId = 0; // Assuming it's the first token minted

    // Employee votes for the research
    const rating = 4;
    const comment = "Impressive methodology!";
    await researchNFT.connect(employee).voteForResearch(tokenId, rating, comment);

    const feedback = await researchNFT.getFeedback(tokenId);
    expect(feedback.length).to.equal(1);
    expect(feedback[0].rating).to.equal(rating);
    expect(feedback[0].comment).to.equal(comment);
});

it("2. Award tokens for research engagement", async function () {
    await researchNFT.rewardEngagement(addr1.address, 10);

    const balance = await researchNFT.tokenBalance(addr1.address);
    expect(balance).to.equal(10);
});
it("3. List NFTs for sale", async function () {
    // Whitelist merchant
    await researchNFT.connect(owner).addMerchant(owner.address);

    // Mint to addr1 (tokenId will be 0 if it's the first mint)
    await researchNFT.connect(owner).mintRewardNFT(owner.address, addr1.address, "ipfs://example-uri");

    // ✅ Confirm the owner of tokenId 0 is addr1
    const newOwner = await researchNFT.ownerOf(0);
    expect(newOwner).to.equal(addr1.address);

    // List tokenId 0 for sale
    await researchNFT.connect(addr1).listNFTForSale(0, ethers.parseEther("1.0"));

    // Check sale info using the correct function
    const [isListed, price] = await researchNFT.getNFTSaleInfo(0);
    expect(isListed).to.be.true;
    expect(price).to.equal(ethers.parseEther("1.0"));
});


it("4. Delist NFTs from sale", async function () {
    // Whitelist merchant
    await researchNFT.connect(owner).addMerchant(owner.address);

    // Mint a new NFT (tokenId 0 will be minted)
    await researchNFT.connect(owner).mintRewardNFT(owner.address, addr1.address, "ipfs://example-uri");

    // ✅ Confirm the owner of tokenId 0 is addr1
    const newOwner = await researchNFT.ownerOf(0);
    expect(newOwner).to.equal(addr1.address);

    // List tokenId 0 for sale
    await researchNFT.connect(addr1).listNFTForSale(0, ethers.parseEther("1.0"));

    // ✅ Confirm the NFT is listed for sale
    const [isListed, price] = await researchNFT.getNFTSaleInfo(0);
    expect(isListed).to.be.true;
    expect(price).to.equal(ethers.parseEther("1.0"));

    // Now delist tokenId 0
    await researchNFT.connect(addr1).delistNFT(0);

    // Check if it's delisted
    const [isDelisted, _] = await researchNFT.getNFTSaleInfo(0);
    expect(isDelisted).to.be.false;
});

it("5. Update sale price of NFT", async function () {
    // Whitelist merchant
    await researchNFT.connect(owner).addMerchant(owner.address);

    // Mint a new NFT (for testing purpose)
    await researchNFT.connect(owner).mintRewardNFT(owner.address, addr1.address, "ipfs://example-uri");

    // Confirm the owner of tokenId 0
    const newOwner = await researchNFT.ownerOf(0);
    expect(newOwner).to.equal(addr1.address);

    // List the NFT for sale
    await researchNFT.connect(addr1).listNFTForSale(0, ethers.parseEther("1.0"));

    // Confirm the NFT is listed for sale with price 1.0
    const [isListed, price] = await researchNFT.getNFTSaleInfo(0);
    expect(isListed).to.be.true;
    expect(price).to.equal(ethers.parseEther("1.0"));

    // Now, update the sale price to 2.0 using the public updateNFTSalePrice function
    await researchNFT.connect(addr1).updateNFTSalePrice(0, ethers.parseEther("2.0"));

    // Check if the sale price has been updated
    const [isListedUpdated, updatedPrice] = await researchNFT.getNFTSaleInfo(0);
    expect(isListedUpdated).to.be.true;
    expect(updatedPrice).to.equal(ethers.parseEther("2.0"));
});



it("6. View NFTs on sale", async function () {
  // Ensure the merchant is added to the whitelist
  await researchNFT.addMerchant(merchant.address);
  
  const vendor = addr2.address; // Example vendor address
  const employee = addr3.address; // Example employee address
  const metadataURI = "https://example.com/metadata/1";

  try {
    // Use the merchant address to mint a reward NFT
    const tx = await researchNFT.connect(merchant).mintRewardNFT(vendor, employee, metadataURI);
    const receipt = await tx.wait(); // Wait for the transaction to be mined

    // Log the entire receipt to inspect all emitted events
    console.log("Transaction receipt:", receipt);

    // Look through the receipt for the RewardMinted event
    const event = receipt.events ? receipt.events.find((event) => event.event === "RewardMinted") : null;
    
    // Log all events in the receipt for debugging
    if (!event) {
      console.error("RewardMinted event not found in the receipt.");
      console.log("All events in receipt:", receipt.events); // Log all events in the receipt for further debugging
      return;
    }

    mintedTokenId = event.args.tokenId.toString(); // Capture the minted token ID
    console.log("Minted Token ID from event:", mintedTokenId);

    // Check if the token exists by calling ownerOf for the minted token ID
    const owner = await researchNFT.ownerOf(mintedTokenId);
    console.log("Owner of token", mintedTokenId, ":", owner);

    // Ensure the token has been successfully minted and owned by the employee
    expect(owner).to.not.equal(ethers.constants.AddressZero); // Ensure token has an owner (not zero address)
    expect(owner).to.equal(employee); // The employee should be the owner of the minted token

    // Now list the NFT for sale
    await researchNFT.listNFTForSale(mintedTokenId, ethers.parseEther("1.0"));

    // Check the sale status of the NFT
    const sale = await researchNFT.getNFTSaleInfo(mintedTokenId);

    // Assert that the NFT is listed for sale
    expect(sale.listed).to.be.true;

    // Optionally, check the price
    expect(sale.price).to.equal(ethers.parseEther("1.0"));
  } catch (err) {
    console.error("Transaction failed:", err);
    expect.fail("Transaction failed: " + err.message); // Replace assert.fail() with expect.fail()
  }
});


it("7. Retrieve all active research NFTs", async function () {
    const metadataURI = "https://example.com/metadata1.json";

    // Step 1: Owner whitelists the merchant
    await researchNFT.connect(owner).whitelistMerchant(merchant.address);

    // Step 2: Mint the NFT
    await researchNFT.connect(merchant).mintRewardNFT(addr1.address, addr2.address, metadataURI);
    console.log("Minted NFT successfully");

    // Step 3: Get the current token ID counter (via getter)
    const tokenIdCounter = await researchNFT.getTokenIdCounter();
    console.log("Current Token ID Counter:", tokenIdCounter.toString());

    // Step 4: Check the total supply of minted NFTs
    const totalSupply = await researchNFT.totalSupply();
    console.log("Total Supply:", totalSupply.toString());

    // Step 5: Fetch the active NFTs by token ID
    const activeNFTs = await researchNFT.getActiveResearchNFTs([tokenIdCounter.toString()]);
    console.log("Active NFTs:", activeNFTs);

    // Step 6: Assert that active NFTs are found
    expect(activeNFTs.length).to.be.greaterThan(0);
});




it("8. Ban a user from interacting with NFTs", async function () {
    await researchNFT.connect(owner).banUser(addr1.address); // ensure owner calls
    const banned = await researchNFT.isBanned(addr1.address);
    expect(banned).to.be.true;
});


it("11. Allow gifting of NFTs to another user", async function () {
    // 1. Whitelist the merchant
    await researchNFT.connect(owner).addMerchant(merchant.address);

    // 2. Mint a Reward NFT to addr1
    const metadataURI = "ipfs://test-metadata";
    await researchNFT.connect(merchant).mintRewardNFT(addr1.address, addr1.address, metadataURI);

    // 3. Gift the NFT from addr1 to addr2
    await researchNFT.connect(addr1).giftNFT(0, addr2.address); // tokenId is 0 for first mint

    // 4. Verify the new owner is addr2
    const newOwner = await researchNFT.ownerOf(0);
    expect(newOwner).to.equal(addr2.address);
});

it("17. Enable NFT lending or renting", async function () {
    // Step 1: Add the owner as a merchant (allow minting)
    await researchNFT.addMerchant(owner.address);

    // Step 2: Mint a reward NFT to addr1 (tokenId 0 should be minted first)
    await researchNFT.mintRewardNFT(owner.address, addr1.address, "ipfs://someURI");

    // Step 3: Ensure addr1 owns the token with tokenId 0
    const ownerOfToken = await researchNFT.ownerOf(0);
    expect(ownerOfToken).to.equal(addr1.address);

    // Step 4: Lend the NFT with tokenId 0 to addr2 for 7 days
    // Ensure this is called by addr1 (the owner of the token)
    await researchNFT.connect(addr1).lendNFT(0, addr2.address, 7); // addr1 lends the NFT to addr2

    // Step 5: Validate the borrower (addr2 should be the current renter)
    const [borrower, returnTime] = await researchNFT.getLendingInfo(0);
    expect(borrower).to.equal(addr2.address);
});



it("19. Enable batch transfer of NFTs", async function () {
    // Step 1: Add the calling address (e.g., addr1) as a whitelisted merchant
    await researchNFT.addMerchant(addr1.address); // Add addr1 as a merchant

    // Step 2: Mint NFTs to the initial owner (e.g., to addr1) from the whitelisted merchant
    await researchNFT.connect(addr1).mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI1"); // Mint NFT with tokenId 0
    await researchNFT.connect(addr1).mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI2"); // Mint NFT with tokenId 1

    // Step 3: Ensure addr1 owns the NFTs
    let owner1 = await researchNFT.ownerOf(0); // Get owner of tokenId 0
    let owner2 = await researchNFT.ownerOf(1); // Get owner of tokenId 1
    expect(owner1).to.equal(addr1.address); // Check that addr1 is the owner of tokenId 0
    expect(owner2).to.equal(addr1.address); // Check that addr1 is the owner of tokenId 1

    // Step 4: Perform batch transfer from addr1 to addr2
    await researchNFT.connect(addr1).batchTransferNFTs(addr2.address, [0, 1]); // Transfer both tokens to addr2

    // Step 5: Ensure the ownership has been transferred to addr2
    owner1 = await researchNFT.ownerOf(0); // Get new owner of tokenId 0
    owner2 = await researchNFT.ownerOf(1); // Get new owner of tokenId 1
    expect(owner1).to.equal(addr2.address); // Check that addr2 is the owner of tokenId 0
    expect(owner2).to.equal(addr2.address); // Check that addr2 is the owner of tokenId 1
});
    it("13. Integrate oracle for real-time data use", async function () {
        const data = await researchNFT.getOracleData();
        expect(data).to.not.equal(0); // or other meaningful check
    });





it("10. Provide update logs/history for NFTs", async function () {
    const tokenId = 1; // Specify a valid tokenId or mint one

    // Add a log for the token
    await researchNFT.addLog(tokenId, "Log entry 1");

    // Fetch the update logs (history) for the NFT
    const history = await researchNFT.getUpdateLogs(tokenId);
    
    // Ensure there is at least one log
    expect(history.length).to.be.above(0);  // Ensure that logs have been added

    // Optionally, you can print the logs to the console for debugging
    console.log("Log history:", history);
});
    it("15. Verify document authenticity via hash", async function () {
        const document = "This is a document content";
        const docHash = keccak256(toUtf8Bytes(document));

        // Check the result using the view function
        const verified = await researchNFT.isDocumentHashVerified(1, docHash);
        expect(verified).to.be.true;

        // Optionally trigger the event
        const tx = await researchNFT.verifyDocumentHash(1, docHash);
        await tx.wait(); // Wait for transaction to complete
    });
it("21. Export metadata and transaction history as JSON/CSV", async function () {
    const metadata = await researchNFT.exportData(1);

    // Ensure the exported data includes the "title" field
    expect(metadata).to.include("title"); // or any expected field like 'uri'
});

it("9. Issue certificate after subscription expiration", async function () {
    // 1. Whitelist the merchant
    await researchNFT.connect(owner).addMerchant(merchant.address);

    // 2. Mint Reward NFT: merchant → addr1
    const mintTx = await researchNFT.connect(merchant).mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI1");
    const mintReceipt = await mintTx.wait();

    // 3. Get tokenId from Transfer event
    const transferEvent = mintReceipt.logs.find(log => log.fragment.name === "Transfer");
    const tokenId = transferEvent.args.tokenId;

    // 4. Confirm ownership
    const tokenOwner = await researchNFT.ownerOf(tokenId);
    expect(tokenOwner).to.equal(addr1.address);

    // 🔥 5. SET a subscription end time in the PAST manually
    const currentTime = (await ethers.provider.getBlock('latest')).timestamp;
    const pastTime = currentTime - (31 * 24 * 60 * 60); // 31 days ago
    await researchNFT.connect(addr1).setSubscriptionEndTime(tokenId, pastTime);

    // ✅ 6. NOW check if subscription is expired
    const expired = await researchNFT.isExpired(tokenId);
    console.log("Is expired?", expired);
    expect(expired).to.be.true;   // Now should be true

    // 7. Issue the certificate
    const tx = await researchNFT.connect(addr1).issueCertificate(tokenId);
    const receipt = await tx.wait();

    // 8. Confirm the CertificateIssued event was emitted
    const event = receipt.logs.find(log => log.fragment.name === "CertificateIssued");
    expect(event.args.tokenId).to.equal(tokenId);

    // 9. Check the certificate struct
    const cert = await researchNFT.certificates(tokenId);
    expect(cert.issued).to.be.true;
});



it("12. Allow auction-style bidding on NFTs", async function () {
    // 1. Whitelist the merchant
    await researchNFT.connect(owner).addMerchant(merchant.address);

    // 2. Mint the NFT from merchant to addr1
    const tx = await researchNFT.connect(merchant).mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI1");
    const receipt = await tx.wait();
    const transferEvent = receipt.logs.find(event => event.fragment.name === "Transfer");
    const tokenId = transferEvent.args.tokenId;

    // 3. Confirm addr1 owns the token
    const ownerOfToken = await researchNFT.ownerOf(tokenId);
    expect(ownerOfToken).to.equal(addr1.address);

    // 4. Start auction by addr1 (owner of token)
    const startBid = ethers.parseEther("1.0");
    const duration = 3600;
    await researchNFT.connect(addr1).startAuction(tokenId, startBid, duration);

    // 5. Confirm auction was set correctly
    const auction = await researchNFT.auctions(tokenId);
    expect(auction.active).to.be.true;
    expect(auction.highestBid).to.equal(startBid);
    expect(auction.ended).to.be.false;

    // 6. Place a valid bid
    await researchNFT.connect(addr2).placeBid(tokenId, { value: ethers.parseEther("1.5") });

    // 7. Verify highest bid and bidder
    const bid = await researchNFT.getHighestBid(tokenId);
    expect(bid.amount).to.equal(ethers.parseEther("1.5"));
    expect(bid.bidder).to.equal(addr2.address);
});

// Updated logic to capture the RewardMinted event
it("14. Automatically extend subscription upon payment", async function () {
  // 1. Whitelist the merchant
  await researchNFT.connect(owner).addMerchant(merchant.address);

  // 2. Mint the NFT
  const mintTx = await researchNFT
    .connect(merchant)
    .mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI1");
  const mintReceipt = await mintTx.wait();

  // 3. Extract the RewardMinted event
  const rewardMintedEvent = mintReceipt.logs
    .map((log) => {
      try {
        return researchNFT.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find((parsed) => parsed && parsed.name === "RewardMinted");

  if (!rewardMintedEvent) {
    throw new Error("RewardMinted event not found");
  }

  const tokenId = rewardMintedEvent.args.tokenId;

  // 4. Set initial subscription end time
  const initialEndTime = await researchNFT.subscriptionEndTime(tokenId);

  // 5. Extend subscription
  const extraDays = 5n;
  const paymentAmount = ethers.parseEther("0.1") * extraDays;
  const extendTx = await researchNFT
    .connect(addr1)
    .extendSubscription(tokenId, extraDays, { value: paymentAmount });
  const extendReceipt = await extendTx.wait();

  // 6. Extract the SubscriptionExtended event
  const extendedEvent = extendReceipt.logs
    .map((log) => {
      try {
        return researchNFT.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find((parsed) => parsed && parsed.name === "SubscriptionExtended");

  if (!extendedEvent) {
    throw new Error("SubscriptionExtended event not found");
  }

  // 7. Verify the extended time
  const newEndTime = await researchNFT.subscriptionEndTime(tokenId);
  expect(newEndTime).to.be.gt(initialEndTime);
});

it("16. Show expiration countdown", async function () {
  await researchNFT.connect(owner).addMerchant(merchant.address);

  const mintTx = await researchNFT.connect(merchant).mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI1");
  const mintReceipt = await mintTx.wait();

  const rewardMintedEvent = mintReceipt.logs
    .map((log) => {
      try {
        return researchNFT.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find((parsed) => parsed && parsed.name === "RewardMinted");

  if (!rewardMintedEvent) {
    throw new Error("RewardMinted event not found");
  }

  const tokenId = rewardMintedEvent.args[0];

  const countdown = await researchNFT.getCountdown(tokenId);
  expect(countdown).to.be.gt(0n);
});


it("20. Add tags or categories to NFTs", async function () {
  await researchNFT.connect(owner).addMerchant(merchant.address);

  const mintTx = await researchNFT.connect(merchant).mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI1");
  const mintReceipt = await mintTx.wait();

  const rewardMintedEvent = mintReceipt.logs
    .map((log) => {
      try {
        return researchNFT.interface.parseLog(log);
      } catch {
        return null;
      }
    })
    .find((parsed) => parsed && parsed.name === "RewardMinted");

  if (!rewardMintedEvent) {
    throw new Error("RewardMinted event not found");
  }

  const tokenId = rewardMintedEvent.args[0];

  await researchNFT.connect(addr1).addTag(tokenId, "AI");

  const tags = await researchNFT.getTags(tokenId);
  expect(tags).to.include("AI");
});


// Updated test code for 18. Notify user before NFT expires
it("18. Notify user before NFT expires", async function () {
    // Whitelist the merchant
    await researchNFT.connect(owner).addMerchant(merchant.address);

    // Mint a reward NFT
    const mintTx = await researchNFT
        .connect(merchant)
        .mintRewardNFT(owner.address, addr1.address, "ipfs://metadataURI1");
    const mintReceipt = await mintTx.wait();

    // Extract the RewardMinted event
    const rewardMintedEvent = mintReceipt.logs
        .map((log) => {
            try {
                return researchNFT.interface.parseLog(log);
            } catch {
                return null;
            }
        })
        .find((parsed) => parsed && parsed.name === "RewardMinted");

    if (!rewardMintedEvent) {
        throw new Error("RewardMinted event not found");
    }

    const tokenId = rewardMintedEvent.args.tokenId;

    // Set expiration to 6 days from now (within the 7-day notification threshold)
    const currentTime = Math.floor(Date.now() / 1000);
    const nearExpiry = currentTime + 6 * 24 * 60 * 60; // 6 days in seconds

    // Set the subscription end time using the correct owner
    await researchNFT.connect(addr1).setSubscriptionEndTime(tokenId, nearExpiry);

    // Check for expiry notification
    const notified = await researchNFT.checkForExpiryNotification(tokenId);
    expect(notified).to.be.true;
});

});
