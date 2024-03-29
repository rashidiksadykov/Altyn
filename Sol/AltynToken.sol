// AltynToken.sol 2023.06.22 started

/* The Altyn Token named ALTYN for the Ethereum version

Follows the EIP20 standard: https://github.com/frozeman/EIPs/blob/94bc4311e889c2c58c561c074be1483f48ac9374/EIPS/eip-20-token-standard.md

2023.06.22


*/

pragma solidity ^0.4.15;

import "./ERC20Token.sol";

contract AltynToken is ERC20Token {
  // enum NFF {  // Founders/Foundation enum
  //   Founders, // 0 Altyn Founders
  //   Foundatn} // 1 Altyn Foundation
  string public constant name   = "Altyn Token";
  string public constant symbol = "ALTYN";
  uint8  public constant decimals = 12;
  uint   public tokensIssued;           // Tokens issued - tokens in circulation
  uint   public tokensAvailable;        // Tokens available = total supply less allocated and issued tokens
  uint   public contributors;           // Number of contributors
  uint   public founderTokensAllocated; // Founder tokens allocated
  uint   public founderTokensVested;    // Founder tokens vested. Same as iTokensOwnedM[pFounderToksA] until tokens transferred. Unvested tokens = founderTokensAllocated - founderTokensVested
  uint   public foundationTokensAllocated; // Foundation tokens allocated
  uint   public foundationTokensVested;    // Foundation tokens vested. Same as iTokensOwnedM[pFoundationToksA] until tokens transferred. Unvested tokens = foundationTokensAllocated - foundationTokensVested
  bool   public icoCompleteB;           // Is set to true when both presale and full ICO are complete. Required for vesting of founder and foundation tokens and transfers of ALTYNs to PIOs
  address private pFounderToksA;        // Address for Founder tokens issued
  address private pFoundationToksA;     // Address for Foundation tokens issued

  // Events
  // ------
  event LogIssue(address indexed Dst, uint Aicos);
  event LogSaleCapReached(uint TokensIssued); // not tokensIssued just to avoid compiler Warning: This declaration shadows an existing declaration
  event LogIcoCompleted();
  event LogBurn(address Src, uint Aicos);
  event LogDestroy(uint Aicos);

  // No Constructor
  // --------------

  // Initialisation/Settings Methods IsOwner but not IsActive
  // -------------------------------

  // Initialise()
  // To be called by deployment owner to change ownership to the sale contract, and do the initial allocations and minting.
  // Can only be called once. If the sale contract changes but the token contract stays the same then ChangeOwner() can be called via AltynICO.ChangeTokenContractOwner() to change the owner to the new contract
  function Initialise(address vNewOwnerA) { // IsOwner c/o the super.ChangeOwner() call
    require(totalSupply == 0);          // can only be called once
    super.ChangeOwner(vNewOwnerA);      // includes an IsOwner check so don't need to repeat it here
    founderTokensAllocated    = 10**20; // 10% or 100 million = 1e20 Aicos
    foundationTokensAllocated = 10**20; // 10% or 100 million = 1e20 Aicos This call sets tokensAvailable
    // Equivalent of Mint(10**21) which can't be used here as msg.sender is the old (deployment) owner // 1 Billion PIOEs    = 1e21 Aicos, all minted)
    totalSupply           = 10**21; // 1 Billion PIOEs    = 1e21 Aicos, all minted)
    iTokensOwnedM[ownerA] = 10**21;
    tokensAvailable       = 8*(10**20); // 800 million [String: '800000000000000000000'] s: 1, e: 20, c: [ 8000000 ] }
    // From the EIP20 Standard: A token contract which creates new tokens SHOULD trigger a Transfer event with the _from address set to 0x0 when tokens are created.
    Transfer(0x0, ownerA, 10**21); // log event 0x0 from == minting
  }

  // Mint()
  // AltynICO() includes a Mint() fn to allow manual calling of this if necessary e.g. re full ICO going over the cap
  function Mint(uint Aicos) IsOwner {
    totalSupply           = add(totalSupply,           Aicos);
    iTokensOwnedM[ownerA] = add(iTokensOwnedM[ownerA], Aicos);
    tokensAvailable = subMaxZero(totalSupply, tokensIssued + founderTokensAllocated + foundationTokensAllocated);
    // From the EIP20 Standard: A token contract which creates new tokens SHOULD trigger a Transfer event with the _from address set to 0x0 when tokens are created.
    Transfer(0x0, ownerA, Aicos); // log event 0x0 from == minting
  }

  // PrepareForSale()
  // stops transfers and allows purchases
  function PrepareForSale() IsOwner {
    require(!icoCompleteB); // Cannot start selling again once ICO has been set to completed
    saleInProgressB = true; // stops transfers
  }

  // ChangeOwner()
  // To be called by owner to change the token contract owner, expected to be to a sale contract
  // Transfers any minted tokens from old to new sale contract
  function ChangeOwner(address vNewOwnerA) { // IsOwner c/o the super.ChangeOwner() call
    transfer(vNewOwnerA, iTokensOwnedM[ownerA]); // includes checks
    super.ChangeOwner(vNewOwnerA); // includes an IsOwner check so don't need to repeat it here
  }

  // Public Constant Methods
  // -----------------------
  // None. Used public variables instead which result in getter functions

  // State changing public methods made pause-able and with call logging
  // -----------------------------
  // Issue()
  // Transfers Aicos tokens to dst to issue them. IsOwner because this is expected to be called from the token sale contract
  function Issue(address dst, uint Aicos) IsOwner IsActive returns (bool) {
    require(saleInProgressB      // Sale is in progress
         && iTokensOwnedM[ownerA] >= Aicos // Owner has the tokens available
      // && Aicos > 0            // Non-zero issue No need to check for this
         && dst != address(this) // Not issuing to this token contract
         && dst != ownerA);      // Not issuing to the owner of this contract - the token sale contract
    if (iTokensOwnedM[dst] == 0)
      contributors++;
    iTokensOwnedM[ownerA] -= Aicos; // There is no need to check this for underflow via a sub() call given the iTokensOwnedM[ownerA] >= Aicos check
    iTokensOwnedM[dst]     = add(iTokensOwnedM[dst], Aicos);
    tokensIssued           = add(tokensIssued,       Aicos);
    tokensAvailable    = subMaxZero(tokensAvailable, Aicos); // subMaxZero() in case a sale goes over, only possible for full ICO, when cap is for all available tokens.
    LogIssue(dst, Aicos);                                    // If that should happen,may need to mint some more PIOEs to allow founder and foundation vesting to complete.
    return true;
  }

  // SaleCapReached()
  // To be be called from the token sale contract when a cap (pre or full) is reached
  // Allows transfers
  function SaleCapReached() IsOwner IsActive {
    saleInProgressB = false; // allows transfers
    LogSaleCapReached(tokensIssued);
  }

  // Functions for manual calling via same name function in AltynICO()
  // =================================================================
  // IcoCompleted()
  // To be be called manually via AltynICO after full ICO ends. Could be called before cap is reached if ....
  function IcoCompleted() IsOwner IsActive {
    require(!icoCompleteB);
    saleInProgressB = false; // allows transfers
    icoCompleteB    = true;
    LogIcoCompleted();
  }

  // SetFFSettings(address vFounderTokensA, address vFoundationTokensA, uint vFounderTokensAllocation, uint vFoundationTokensAllocation)
  // Allows setting Founder and Foundation addresses (or changing them if an appropriate transfer has been done)
  //  plus optionally changing the allocations which are set by the constructor, so that they can be varied post deployment if required re a change of plan
  // All values are optional - zeros can be passed
  // Must have been called with non-zero Founder and Foundation addresses before Founder and Foundation vesting can be done
  function SetFFSettings(address vFounderTokensA, address vFoundationTokensA, uint vFounderTokensAllocation, uint vFoundationTokensAllocation) IsOwner {
    if (vFounderTokensA    != address(0)) pFounderToksA    = vFounderTokensA;
    if (vFoundationTokensA != address(0)) pFoundationToksA = vFoundationTokensA;
    if (vFounderTokensAllocation > 0)    assert((founderTokensAllocated    = vFounderTokensAllocation)    >= founderTokensVested);
    if (vFoundationTokensAllocation > 0) assert((foundationTokensAllocated = vFoundationTokensAllocation) >= foundationTokensVested);
    tokensAvailable = totalSupply - founderTokensAllocated - foundationTokensAllocated - tokensIssued;
  }

  // VestFFTokens()
  // To vest Founder and/or Foundation tokens
  // 0 can be passed meaning skip that one
  // No separate event as the LogIssue event can be used to trace vesting transfers
  // To be be called manually via AltynICO
  function VestFFTokens(uint vFounderTokensVesting, uint vFoundationTokensVesting) IsOwner IsActive {
    require(icoCompleteB); // ICO must be completed before vesting can occur. djh?? Add other time restriction?
    if (vFounderTokensVesting > 0) {
      assert(pFounderToksA != address(0)); // Founders token address must have been set
      assert((founderTokensVested  = add(founderTokensVested,          vFounderTokensVesting)) <= founderTokensAllocated);
      iTokensOwnedM[ownerA]        = sub(iTokensOwnedM[ownerA],        vFounderTokensVesting);
      iTokensOwnedM[pFounderToksA] = add(iTokensOwnedM[pFounderToksA], vFounderTokensVesting);
      LogIssue(pFounderToksA,          vFounderTokensVesting);
      tokensIssued = add(tokensIssued, vFounderTokensVesting);
    }
    if (vFoundationTokensVesting > 0) {
      assert(pFoundationToksA != address(0)); // Foundation token address must have been set
      assert((foundationTokensVested  = add(foundationTokensVested,          vFoundationTokensVesting)) <= foundationTokensAllocated);
      iTokensOwnedM[ownerA]           = sub(iTokensOwnedM[ownerA],           vFoundationTokensVesting);
      iTokensOwnedM[pFoundationToksA] = add(iTokensOwnedM[pFoundationToksA], vFoundationTokensVesting);
      LogIssue(pFoundationToksA,       vFoundationTokensVesting);
      tokensIssued = add(tokensIssued, vFoundationTokensVesting);
    }
    // Does not affect tokensAvailable as these tokens had already been allowed for in tokensAvailable when allocated
  }

  // Burn()
  // For use when transferring issued PIOEs to PIOs
  // To be be called manually via AltynICO or from a new transfer contract to be written which is set to own this one
  function Burn(address src, uint Aicos) IsOwner IsActive {
    require(icoCompleteB);
    iTokensOwnedM[src] = subMaxZero(iTokensOwnedM[src], Aicos);
    tokensIssued       = subMaxZero(tokensIssued, Aicos);
    totalSupply        = subMaxZero(totalSupply,  Aicos);
    LogBurn(src, Aicos);
    // Does not affect tokensAvailable as these are issued tokens that are being burnt
  }

  // Destroy()
  // For use when transferring unissued PIOEs to PIOs
  // To be be called manually via AltynICO or from a new transfer contract to be written which is set to own this one
  function Destroy(uint Aicos) IsOwner IsActive {
    require(icoCompleteB);
    totalSupply     = subMaxZero(totalSupply,     Aicos);
    tokensAvailable = subMaxZero(tokensAvailable, Aicos);
    LogDestroy(Aicos);
  }

  // Fallback function
  // =================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() {
    revert(); // reject any attempt to access the token contract other than via the defined methods with their testing for valid access
  }
} // End AltynToken contract
