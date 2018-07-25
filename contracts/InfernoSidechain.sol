pragma solidity ^0.4.18;


import "./ECRecovery.sol";
import "./MerkleProof.sol";



/*
Contract for operating and maintaining an Inferno Sidechain

This is an Ethereum plasma-like sidechain using Merkle Proofs and Time-Delayed Withdrawls





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


//A lava packet but for the sidechain 
struct TXPacket
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


contract InfernoSidechain   {

  //mapping(address => mapping (address => uint256)) balances;


  using SafeMath for uint;


   address public miningKingContract;

   address public sidechainToken;


   address public merkleStateRootHash;

   // ethBlockNumber => root hash
   mapping(uint256 => bytes32) merkleStateBlockHash;
   mapping(uint256 => address) merkleStateBlockAuthority;

   //locked tokens - only the sidechainToken type is allowed
   mapping(address => uint256) balances;

   //hash -> signature
   //must verify endpoint TX in order to use them to unlock and to prove fraud
   mapping(bytes32 => bytes32) verifiedEndpointTransaction;


   // 0xBTC is 0xb6ed7644c69416d67b522e20bc294a9a9b405b31;
  constructor(address sToken, mkContract) public  {
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

       require( merkleStateBlockHashes[ethBlockNumber] = 0x0 );

       merkleStateBlockHashes[ethBlockNumber] = stateBlockHash;
       merkleStateBlockAuthority[ethBlockNumber] = msg.sender;


       //keep appending the block hashes onto the state root hash ..
       //is this the correct way to append them ??
       if(merkleStateRootHash == 0x0)
       {
         merkleStateRootHash = keccak256(stateBlockHash)
       }else{
         merkleStateRootHash = keccak256(merkleStateRootHash , stateBlockHash);
       }

   }


   //able to use lava ?  approveAndCall?

   //Once they are deposited and locked, they belong to the same Eth Address but on the sidechain
   function depositTokensToSidechain(from, tokens) public returns (bool)
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

   function startFundsUnlock( proof, root, leaf , sigHash  ) returns (bool)
   {
     //check the lava packet
     //can do lots of computation but do not do too much storage as that is gas-costly !


     require( verifiedEndpointTransaction[sigHash] )
      //use merkle proof

   }

   /*
   Prove that a fund unlock which is in progress is FRAUDULENT in order to steal and claim the staked tokens

   You will get paid if you prove that there is a conflicting leaf in the merkleStateRootHash  - like a duplicate  lava packet etc etc
   */
   function cancelFundsUnlock( proof, root, leaf  ) returns (bool)
   {
      //use merkle proof





   }

   function finishFundsUnlock( proof, root, leaf  ) returns (bool)
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
