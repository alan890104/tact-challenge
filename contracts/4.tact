import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

const DEFAULT_TON_VALUE: Int = ton("0.05"); // TODO: Change this

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

message NftWithdrawal {
    queryId: Int as uint64;
    nftAddress: Address;
}

contract Task4 with Deployable {
    seed: Int as uint128;
    lockEndTime: Int as uint32 = 0;
    nftAddress: Address? = null;
    nftOwner: Address? = null;


    init(seed: Int){
        self.seed = seed;
    }

    receive(msg: OwnershipAssigned){
        let ctx: Context = context();
        if (self.nftAddress != null) {
            // return nft back to sender
            send(SendParameters{
                to: ctx.sender,
                value: 0,
                bounce: false,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: Transfer{
                    queryId: 0,
                    newOwner: msg.prevOwner,
                    responseDestination: myAddress(),
                    customPayload: null,
                    forwardAmount: DEFAULT_TON_VALUE,
                    forwardPayload: emptySlice()
                }.toCell()
            });
        } else {
            let payload: Slice = msg.forwardPayload;
            self.nftAddress = ctx.sender;
            self.lockEndTime = payload.loadUint(32) + now();
            self.nftOwner = msg.prevOwner;
        }
    }

    receive(msg: NftWithdrawal){
        let ctx: Context = context();
        require(ctx.sender == self.nftOwner, "Invalid sender");
        if (now() < self.lockEndTime) {
            send(SendParameters{
                to: ctx.sender,
                value: 0,
                bounce: false,
                mode: SendRemainingValue,
                body: "NFT is still locked".asComment()
            });
        } else {
            send(SendParameters{
                to: self.nftAddress!!,
                value: 0,
                bounce: false,
                mode: SendRemainingValue + SendIgnoreErrors,
                body: Transfer{
                    queryId: 0,
                    newOwner: self.nftOwner!!,
                    responseDestination: myAddress(),
                    customPayload: null,
                    forwardAmount: DEFAULT_TON_VALUE,
                    forwardPayload: emptySlice()
                }.toCell()
            });
            self.nftAddress = null;
            self.nftOwner = null;
            self.lockEndTime = 0;
        }
    }

    get fun time(): Int {
        if (self.lockEndTime == 0 || self.lockEndTime > now()) {
            return 0;
        }
        return self.lockEndTime - now();
    }

    get fun nft(): Address? {
        return self.nftAddress;
    }

    get fun owner(): Address? {
        return self.nftOwner;
    }
}