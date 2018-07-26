pragma solidity ^0.4.18;


import "./ECRecovery.sol";
import "./MerkleProof.sol";



/*
Contract for operating and maintaining an Inferno Sidechain

This is an Ethereum plasma-like sidechain using Merkle Proofs and Time-Delayed Withdrawls


https://ethresear.ch/t/minimal-viable-plasma/426


*/




/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


/*

This is a King Of The Hill contract which requires Proof of Work (hashpower) to set the king

This global non-owned contract proxy-mints 0xBTC through a personally-owned mintHelper contract (MintHelper.sol)

*/

contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract MiningKingInterface {
    function getMiningKing() public returns (address);
    function transferKing(address newKing) public;
    function mint(uint256 nonce, bytes32 challenge_digest) returns (bool);

    event TransferKing(address from, address to);
}


struct BlockHeader
{
  uint blockNumber;
  bytes32 stateRootHash;
  address authority;

  //uint ethBlockNumber;
}


//A lava packet but for the sidechain
/*
struct LavaPacket
{
 address from;
 address to;
 address token;
 uint256 tokens;
 uint256 relayerReward;
 uint256 expires;
 uint256 nonce;
 bytes signature;
}
*/


/*
[blknum1, txindex1, oindex1, sig1, # Input 1
 blknum2, txindex2, oindex2, sig2, # Input 2
 newowner1, denom1,                # Output 1
 newowner2, denom2,                # Output 2
 fee]
*/


/*

Each transaction has 2 inputs and 2 outputs, and the sum of the denominations of the outputs
plus the fee must equal the sum of the denominations of the inputs.
 The signatures must be signatures of all the other fields in the transaction,
 with the private key corresponding to the owner of that particular output.
  A deposit block has all input fields, and the fields for the second output, zeroed out.
   To make a transaction that spends only one UTXO, a user can zero out all fields
   for the second input.*/

struct TxInput
{
  uint blockNumber;
  uint txIndex;
  uint oIndex;
  bytes32 signature;
}

struct TxOutput
{
  address newOwner;
  uint amount; //denom
}


struct Transaction
{
  TxInput input1;
  TxInput input2;
  TxOutput output1;
  TxOutput output2;
  uint fee;
}


//Plasma Implementation using Proof Of Work to determine block hash authority
contract InfernoSidechain   {

  //mapping(address => mapping (address => uint256)) balances;


  using SafeMath for uint;

   uint plasmaBlockNumber = 0;

   address public miningKingContract;

   address public sidechainToken;


   address public merkleStateRootHash;

   // blockNumber => root hash
   mapping(uint256 => BlockHeader) merkleStateBlock ;


   //locked tokens - only the sidechainToken type is allowed
   mapping(address => uint256) balances;

   //hash -> signature
   //must verify endpoint TX in order to use them to unlock and to prove fraud
   mapping(bytes32 => bytes32) verifiedEndpointTransaction;


   // 0xBTC is 0xb6ed7644c69416d67b522e20bc294a9a9b405b31;
  constructor(address sToken, address mkContract) public  {
    sidechainToken = sToken;
    miningKingContract = mkContract;
  }


  //do not allow ether to enter
  function() public payable {
      revert();
  }

  /*
  Round Robin Chain Authority
  Based on Proof of Work, EIP 918 and MiningKing Contract
  */
  function getChainAuthority() public returns (address)
  {
    return MiningKingInterface(relayKingContract).getMiningKing();
  }

  /*
    Each block number, the king can add a state root hash   (should be each 0xBTC epoch?)

    [There should be a reward for the king doing this - maybea fee when someone uses their state root hash to exit]

    [Remember that it is possible for the king to submit bogus(EMPTY) state root hashes]


    To get the stateBlockHash, one must simply 'combine' the solidity keccak256 hashes of all the Sidechain TX Signatures   (hashes ?)
  */
   function addRootHash(bytes32 stateBlockHash) public   {

       require(msg.sender == getChainAuthority());

       uint ethBlockNumber = block.number;



       require( merkleStateBlock[plasmaBlockNumber] = 0x0 );


       //keep appending the block hashes onto the state root hash ..
       //is this the correct way to append them ??
       if(merkleStateRootHash == 0x0)
       {
         merkleStateRootHash = keccak256(stateBlockHash)
       }else{
         merkleStateRootHash = keccak256(merkleStateRootHash , stateBlockHash);
       }


       merkleStateBlock[plasmaBlockNumber] = BlockHeader({
         blockNumber: plasmaBlockNumber;
         stateRootHash: merkleStateRootHash; // the combined hash of ALL elements all together
         authority: msg.sender;

         })


      plasmaBlockNumber+=1;

   }


   //able to use lava ?  approveAndCall?

   //depositTokensToSidechain
   //Once they are deposited and locked, they belong to the same Eth Address but on the sidechain
   function deposit(from, tokens) public returns (bool)
   {
     //requires approval first
     require(  ERC20Interface(sidechainToken).transferFrom( from, this, tokens )  );

     balances[from] = balances[from].add(tokens);

     return true;
   }



   // method = 'transfer' typically
   /*
    This method makes the contract aware of the specific details of a 'lava packet' transaction
    This method must be ran before starting an unlock with a sigHash or before proving fraud with a sigHash

   */
   function identifyEndpointTransaction(string method, address from, address to, address token, uint256 tokens, uint256 relayerReward,
                                     uint256 expires, uint256 nonce, bytes signature)
   {

     bytes32 sigHash = getLavaTypedDataHash(method,from,to,token,tokens,relayerReward,expires,nonce);

     address recoveredSignatureSigner = ECRecovery.recover(sigHash,signature);

     require( recoveredSignatureSigner == from );

     verifiedEndpointTransaction[sigHash] = signature;

   }

/**
  Exit tokens out of the sidechain - has a one week delay based on ETH blocks

  Have to stake some tokens to initiate an unlock incase you are lying !


  This basically proves that there are king-mined LavaPackets that exist
  which show that funds have been moved to the exiting owner.
**/


//startExit(uint256 plasmaBlockNum, uint256 txindex, uint256 oindex, bytes tx, bytes proof, bytes confirmSig)

  /*
  (i) the Plasma block number and tx index in which the UTXO was created,
  (ii) the output index, (iii) the transaction containing that UTXO,
  (iv) a Merkle proof of the transaction, and
  (v) a confirm signature from each of the previous owners of the
  now-spent outputs that were used to create the UTXO.
  */

   function startExit(uint plasmaBlockNumber, uint txIndex, uint oIndex , bytes tx, bytes proof, bytes confirmSig   ) returns (bool)
   {
     //  proof, root, leaf , sigHash
     //can do lots of computation but do not do too much storage as that is gas-costly !

      //check confirm signature from each of the previous owners of the now-spent outputs that were used to create the UTXO.


      //use merkle proof

   }

   /*
   Prove that a fund unlock which is in progress is FRAUDULENT in order to steal and claim the staked tokens

   You will get paid if you prove that there is a conflicting leaf in the merkleStateRootHash  - like a duplicate  lava packet etc etc
   */

   //challengeExit(uint256 exitId, uint256 plasmaBlockNum, uint256 txindex, uint256 oindex, bytes tx, bytes proof, bytes confirmSig)
   function challengeExit( uint256 exitId, uint256 plasmaBlockNum, uint256 txindex, uint256 oindex, bytes tx, bytes proof, bytes confirmSig  ) returns (bool)
   {
      //use merkle proof





   }

   function finishExit(   ) returns (bool)
   {
      //use merkle proof


     //transfer tokens out to the recipient

   }



   function getLavaTypedDataHash(bytes methodname, address from, address to, address token, uint256 tokens, uint256 relayerReward,
                                     uint256 expires, uint256 nonce) public constant returns (bytes32)
   {
         bytes32 hardcodedSchemaHash = 0x8fd4f9177556bbc74d0710c8bdda543afd18cc84d92d64b5620d5f1881dceb37; //with methodname


        bytes32 typedDataHash = sha3(
            hardcodedSchemaHash,
            sha3(methodname,from,to,this,token,tokens,relayerReward,expires,nonce)
          );

        return typedDataHash;
   }

/*
  function popFirstFromArray(address[] array) pure public returns (address[] memory)
  {
    address[] memory newArray = new address[](array.length-1);

    for (uint i=0; i < array.length-1; i++) {
      newArray[i] =  array[i+1]  ;
    }

    return newArray;
  }

 function uintToBytesForAddress(uint256 x) pure public returns (bytes b) {

      b = new bytes(20);
      for (uint i = 0; i < 20; i++) {
          b[i] = byte(uint8(x / (2**(8*(31 - i)))));
      }

      return b;
    }


 function bytesToAddress (bytes b) pure public returns (address) {
     uint result = 0;
     for (uint i = b.length-1; i+1 > 0; i--) {
       uint c = uint(b[i]);
       uint to_inc = c * ( 16 ** ((b.length - i-1) * 2));
       result += to_inc;
     }
     return address(result);
 }
*/



}
