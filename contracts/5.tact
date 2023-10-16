import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smartcontract contains a bunch of different NFTs.
  A user brings his NFT and sends it to the smartcontract, with 2.1TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smartcontract randomly chooses some nft from the already available nfts and gives it to user in exchange for the brought nft.
  Admin address can deposit NFTs without swap logic. 
  Admin can withdrawal all NFTs + all TONs that was collected from users as fees.
  Implement getter that will show NFT addresses on the balance of smartcontract. X
  Implement getter that will show amount of fees collected.

  All in all, smartcontract should have this logic:
  Transactions
  * AdminWithdrawalFees 
   - sc should check that sender is admin / otherwise throw "Insufficient privelegies" (BUG privileges)
   - sc should send all collected fees to admin except 0.1tons
  * AdminWithdrawalAllNFTs
   - sc should send max 100 nfts in one batch
   - sc should check that incoming tx tons value will be enougth for nft withdrawal (ton("1") + self.total * ton("0.08")) thorw "Insufficent funds" otherwise
   - sc should check that sender is admin, throw "Invalid sender" otherwise
   - sc should send nft one by one to admin 
  * OwnershipAssigned 
   - if prevOwner is owner (admin) address, then add nft to collection
   - if value of ton attached is les then 2.1 TON then stop execution and return nft back
   - randomly select nft to send from all nfts that smartcontract have
   - send selected nft to sender with all remaining balance (except of admin profit / collected fees from this and other swaps)
  
  Getters
  * fees
   - return how much collected fees is available to withdrawal for admin (all fees - 0.1ton)
  * nfts
   - should return dict of stored nfts with nft ids as keys and nfts address as values 
*/

const DEFAULT_FORWARD_AMOUNT: Int = ton("0");

message AdminWithdrawalFees {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message AdminFetchFees {
  queryId: Int as uint64;
}

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

contract Task5 with Deployable {
  seed: Int as uint128;
  owner: Address;
  collected_fees: Int as coins = 0;
  nfts: map<Int as uint16, Address>;
  index: Int as uint16 = 1;
  
  init(seed: Int, owner: Address) {
    self.owner = owner;
    self.seed = seed;
  }

  receive(msg: OwnershipAssigned) {
    let ctx: Context = context();
    if(msg.prevOwner == self.owner) {
      // Add NFT to collection
      self.nfts.set(self.index, ctx.sender);
      self.index = self.index + 1;
      return;
    }
    if(ctx.value < ton("2.1")) {
      // Send NFT back
      send(SendParameters{
        to: ctx.sender,
        value: 0,
        bounce: false,
        mode: SendRemainingValue,
        body: Transfer { 
          queryId: 0,            
          newOwner: msg.prevOwner, 
          responseDestination: myAddress(), 
          customPayload: null, 
          forwardAmount: DEFAULT_FORWARD_AMOUNT, 
          forwardPayload: emptySlice() 
        }.toCell()
      });
      return;
    }

    // Randomly select NFT
    let rndIdx: Int = random(0, self.index);
    let nftAddr: Address = self.nfts.get(rndIdx)!!;
    send(SendParameters{
      to: nftAddr,
      value: ctx.value - ton("2"),
      bounce: false,
      mode: 0,
      body: Transfer { 
        queryId: 0,            
        newOwner: msg.prevOwner, 
        responseDestination: myAddress(), 
        customPayload: null, 
        forwardAmount: DEFAULT_FORWARD_AMOUNT, 
        forwardPayload: emptySlice() 
      }.toCell()
    });
    self.nfts.set(rndIdx, ctx.sender);
    self.collected_fees = self.collected_fees + ton("2");
  }

  receive(msg: AdminWithdrawalFees) {
    let ctx: Context = context();
    require(ctx.sender  == self.owner, "Insufficient privelegies");
    if (self.collected_fees > ton("0.1")) {
      send(SendParameters{
        to: self.owner,
        value: self.collected_fees - ton("0.1"),
        bounce: false,
        mode: 0,
        body: AdminFetchFees { 
          queryId: 0
        }.toCell()
      });
      self.collected_fees = 0;
    }
  }

  receive(msg: AdminWithdrawalAllNFTs) {
    let ctx: Context = context();
    require(ctx.value > ton("1") + self.index * ton("0.08"), "Insufficent funds");
    require(ctx.sender  == self.owner, "Invalid sender");
    let x: Int = self.index;
    if (self.index > 100) {
      x = 100;
    }
    do {
      send(SendParameters{
        to: self.nfts.get(x)!!,
        value: ton("0.08"),
        bounce: false,
        mode: 0,
        body: Transfer { 
          queryId: 0,            
          newOwner: self.owner, 
          responseDestination: myAddress(), 
          customPayload: null, 
          forwardAmount: DEFAULT_FORWARD_AMOUNT, 
          forwardPayload: emptySlice() 
        }.toCell()
      });
    } until (x <= 1);
  }

  get fun fees(): Int {
    if(self.collected_fees < ton("0.1")){
      return 0;
    }
    return self.collected_fees - ton("0.1");
  }
  
  get fun nfts(): map<Int as uint16, Address> {
    return self.nfts;
  }
}
