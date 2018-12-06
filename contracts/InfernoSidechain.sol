pragma solidity ^0.4.18;




/*
Contract for operating and maintaining an Inferno Sidechain

Only stores a simple merkle tree root hash on the Ethereum Mainnet


______

The mapping 'blocks' is a collection of blocks which all reference some other previous block.
Sidechain Nodes must determine which of these blocks has the most valid blocks sequentially behind it (ending at the genesis block, and the node must have all TX data for each block -- synced)


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


contract EIP918Interface {
  function lastRewardTo() public returns (address);
  function epochCount() public returns (uint);

  function lastRewardAmount() public returns (uint);
  function lastRewardEthBlockNumber() public returns (uint);

  function totalSupply() public constant returns (uint);
  function getMiningDifficulty() public constant returns (uint);
  function getMiningTarget() public constant returns (uint);
  function getMiningReward() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);

  function mint(uint256 nonce, bytes32 challenge_digest) public returns (bool success);

  event Mint(address indexed from, uint reward_amount, uint epochCount, bytes32 newChallengeNumber);

}



contract InfernoSidechain   {
    using SafeMath for uint;

    uint lastBlockMiningEpoch;

    uint deepestDepth;

    uint REQUIRED_CONFIRMATION_BLOCKS = 1024;

   // rootHash => Block
   mapping(bytes32 => Block) public blocks;

   //utxo hash -> import
   mapping(bytes32 => GenesisImport) public imports;

   struct Block
   {
    bytes32 root;
    bytes32 leaf; //root of previous block, also the first element of the hash to makes up Root

    uint depth; //the number of block parents
    uint epochCount; //for sequentiality
   }

   struct GenesisImport
   {
     bytes32 id; //utxo id
     uint sender;
     address token;
     uint tokens;
   }


    address public miningContract;



   // 0xBTC is 0xb6ed7644c69416d67b522e20bc294a9a9b405b31;
  constructor(address mContract) public  {
    miningContract = mContract;

    //add genesis block
    lastBlockMiningEpoch = getMiningEpoch();
    blocks[0x0] = Block(0x0,0x0,0,lastBlockMiningEpoch);
  }


  //do not allow ether to enter
  function() public payable {
      revert();
  }

  /*
  Based on Proof of Work, EIP 918 and Mining Contract

  This will typically return a smart contract but one which implements proper forwarding methods
  */
  function getMiningAuthority() public returns (address)
  {
    return EIP918Interface(miningContract).lastRewardTo();
  }

  function getMiningEpoch() public returns (uint)
  {
    return EIP918Interface(miningContract).epochCount();
  }



  /*
  Sidechain TX Formats   rev 1
  //fee always in 0xBTC

  import(from, token, tokens,fee)
  transfer(from,to,token,tokens,fee)
  export(from, token, tokens , fee)

  PROBLEM: A contentious 51% attacker can make new 'exit' tx with no parents/history and steal tokens
  ...perhaps use UTXO and prove them on each new block added ? ...prove them on exit ?

  */


  /*
  In this case, the leaf is the root of the previous block

  */
  function addNewBlock(

      bytes32 root,
      bytes32 leaf,
      bytes32[] proof

    )
      public
      returns (bool)
    {
      require(msg.sender == getMiningAuthority());
      require(blocks[leaf].root == leaf || leaf == 0x0); //must build off of an existing block OR the genesis block
      require(lastBlockMiningEpoch <  getMiningEpoch()); //one new sidechain block per Mining Round


      bytes32 computedHash = leaf;

      for (uint256 i = 0; i < proof.length; i++) {
        bytes32 proofElement = proof[i];

        if (computedHash < proofElement) {
          computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
        } else {
          computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
        }
      }

      require(computedHash == root);



      //currentRootHash = root; //update to the new overall chain state
      lastBlockMiningEpoch = getMiningEpoch();



      bytes32 nextParentRoot = leaf;

      Block memory parent = blocks[nextParentRoot];


      uint thisBlockDepth = parent.depth.add(1);

      if( thisBlockDepth > deepestDepth )
      {
        deepestDepth = thisBlockDepth;
      }


      blocks[root] = Block(root,leaf,thisBlockDepth,lastBlockMiningEpoch);


      return true;
    }



    function blockHasDeepestDepth(bytes32 root) view returns (bool)
    {
      Block memory b = blocks[root];
      return b.depth == deepestDepth;
    }


    //import tokens
    // this makes a new UTXO hash .... saved in contract
    function importTokensToSidechain(address token, uint tokens, bytes32  input)
    {
      uint nextImportedTokenIndex = 0;//gobal and gets incremented ... (draft)

      bytes32 id = SHA3(msg.sender, token, tokens, block.number, input);

      require( imports[id].id == 0); //must not exist

      imports[id] = GenesisImport(id, msg.sender, token, tokens);


    }



    //do UTXO proofing every block submission... Actually i think this is impossible

    //export tokens
    /*
    User must provide a root for a head-block of a branch which has a depth
    equal to the 'deepestDepth'  global.   We compute its depth to make sure.
    Then,   Require a UTXO proof that there is a withdrawl tx in a block
    under that heads sidechain branch which has at least REQUIRED_CONFIRMATION_BLOCKS confirms.
    the UTXO must begin at the import UTXO hash.
    */
    //still  a WIP
    /*
    utxoProof - proves that there is a lineage of ECDSA signatures from the sidechain export UTXO to the genesis import UXTO
    ????merkleProof - proves that there are X confirmations on the sidechain export UXTO being mined and that its branch is the longest branch
    */

    function exportTokensFromSidechain(
      uint amount,
      bytes32 rootHash,
      bytes32 merkleProof
    )
    {
      address from = msg.sender;


    }


}
