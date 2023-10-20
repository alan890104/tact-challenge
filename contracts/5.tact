import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.
  Implement getter that will return NFT addresses held by the smart contract.
  Implement getter that will return the amount of admin`s profit collected.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit 
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin 
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned 
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
  
  Getters
  * profit
   - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  * nfts
   - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values 
     the order of NFTs in this dictionary doesn't matter
*/


message AdminWithdrawalProfit {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}


message BatchTx {
  startIdx: Int as uint16;
  queryId: Int as uint64;
}


message AdminFetchProfit {
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

const SPLIT_THRESHOLD: Int = 250;

contract Task5 with Deployable {
  // seed: Int as uint128;
  owner: Address;
  nfts: map<Int as uint16, Address>;
  totalNftsHeld: Int as uint16 = 0;
  
  init(seed: Int, owner: Address) {
    self.owner = owner;
    // self.seed = seed;
  }


  receive(msg: OwnershipAssigned) {
    let ctx: Context = context();
    if(msg.prevOwner == self.owner) {
      // Add NFT to collection
      self.nfts.set(self.totalNftsHeld, ctx.sender);
      self.totalNftsHeld = self.totalNftsHeld + 1;
      return;
    }

    if(ctx.value < ton("2.1")) {
      // Send NFT back
      send(SendParameters{
        to: ctx.sender,
        value: 0,
        mode: SendRemainingValue + SendIgnoreErrors,
        body: Transfer { 
          queryId: msg.queryId,            
          newOwner: msg.prevOwner, 
          responseDestination: msg.prevOwner, 
          customPayload: null, 
          forwardAmount: 0, 
          forwardPayload: emptySlice() 
        }.toCell()
      });
      return;
    }

    // nativeReserve(ton("2"), 0);
    let rndIdx: Int = random(0, self.totalNftsHeld);
    if (rndIdx == self.totalNftsHeld) {
      // Alan: Send back NFT that sender just sent
      send(SendParameters{
        to: ctx.sender,
        value: ctx.value - ton("2"),
        // value: 0,
        // mode: SendRemainingValue + SendIgnoreErrors,
        body: Transfer { 
          queryId: msg.queryId,            
          newOwner: msg.prevOwner, 
          responseDestination: msg.prevOwner, 
          customPayload: null, 
          forwardAmount: 0, 
          forwardPayload: emptySlice() 
        }.toCell()
      });
      return;
    }
    // Alan: Send the selected NFT to the sender
    send(SendParameters{
      to: self.nfts.get(rndIdx)!!,
      value: ctx.value - ton("2"),
      // value: 0,
      // mode: SendRemainingValue + SendIgnoreErrors,
      body: Transfer { 
        queryId: msg.queryId,            
        newOwner: msg.prevOwner, 
        responseDestination: msg.prevOwner, 
        customPayload: null, 
        forwardAmount: 0, 
        forwardPayload: emptySlice() 
      }.toCell()
    });
    // Alan: Replace selected NFT with the one that sender just sent
    self.nfts.set(rndIdx, ctx.sender);
  }

  receive(msg: AdminWithdrawalProfit) {
    let ctx: Context = context();
    require(ctx.sender  == self.owner, "Insufficient privelegies");
    if (myBalance() > ton("0.1")) {
      nativeReserve(ton("0.1"), 0);
      send(SendParameters{
        to: self.owner,
        value: 0,
        mode: SendRemainingBalance,
        body: AdminFetchProfit { 
          queryId: msg.queryId
        }.toCell()
      });
    }
  }

  receive(msg: AdminWithdrawalAllNFTs) {
    let ctx: Context = context();
    require(ctx.value >= ton("1") + self.totalNftsHeld * ton("0.08"), "Insufficent funds");
    require(ctx.sender  == self.owner, "Invalid sender");
    if (self.totalNftsHeld < SPLIT_THRESHOLD){
      let x: Int = 0;
      let body: Cell = Transfer { 
        queryId: msg.queryId,            
        newOwner: self.owner, 
        responseDestination: self.owner,
        customPayload: null, 
        forwardAmount: 0, 
        forwardPayload: emptySlice()
      }.toCell();
      while(x < self.totalNftsHeld) {
        send(SendParameters{
          to: self.nfts.get(x)!!,
          value: ton("0.0123"),
          mode: 0,
          body: body
        });
        x = x + 1;
      }
      self.totalNftsHeld = 0;
      self.nfts = emptyMap();
      return;
    }
    send(SendParameters{
      to: myAddress(),
      value: 0,
      mode: SendRemainingValue,
      body: BatchTx { 
        queryId: msg.queryId,      
        startIdx: 0
      }.toCell()
    });
  }

  receive(msg: BatchTx) {
    let x: Int = msg.startIdx;
    let body: Cell = Transfer { 
        queryId: msg.queryId,            
        newOwner: self.owner, 
        responseDestination: self.owner,
        customPayload: null, 
        forwardAmount: 0, 
        forwardPayload: emptySlice()
      }.toCell();
    while(x < self.totalNftsHeld && x < msg.startIdx + SPLIT_THRESHOLD) {
      send(SendParameters{
        to: self.nfts.get(x)!!,
        value: ton("0.0123"),
        mode: 0,
        body: body
      });
      x = x + 1;
    }
    if (x < self.totalNftsHeld) {
      send(SendParameters{
        to: myAddress(),
        value: 0,
        mode: SendRemainingValue,
        body: BatchTx{
          startIdx: x,
          queryId: msg.queryId
        }.toCell()
      });
      return;
    }
    self.totalNftsHeld = 0;
    self.nfts = emptyMap();
  }

  get fun profit(): Int {
    if(myBalance() < ton("0.1")){
      return 0;
    }
    return myBalance() - ton("0.1");
  }
  
  get fun nfts(): map<Int as uint16, Address> {
    return self.nfts;
  }
}
