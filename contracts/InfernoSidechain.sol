pragma solidity ^0.4.18;




/*
Contract for operating and maintaining an Inferno Sidechain
Only stores a simple merkle tree root hash on the Ethereum Mainnet


______

The mapping 'blocks' is a collection of blocks which all reference some other previous block.
Sidechain Nodes must determine which of these blocks has the most valid blocks sequentially behind it (ending at the genesis block, and the node must have all TX data for each block -- synced)


*/



  /*
  Sidechain TX Formats   rev 1
  //fee always in 0xBTC

  import(from, token, tokens,fee)
  transfer(from,to,token,tokens,fee)
  export(from, token, tokens , fee)


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

    uint totalBlockCount;

    uint REQUIRED_DEPTH_BLOCKS = 1024;

    uint REQUIRED_CONFIRMATION_BLOCKS = 256;

   // rootHash => Block
   mapping(bytes32 => Block) public blocks;

   //utxo hash -> import
   mapping(bytes32 => GenesisImport) public imports;

   mapping(bytes32 => bool) public validatedExitTransactions;

   //Burn tokens to communicate with peers who
   //require minimum burned tokens.
   //Allows for peer blacklisting
   mapping(address => uint) public burnedTokens;


   struct Block
   {
    bytes32 root;
    bytes32 leaf; //root of previous block

    uint depth; //the number of block parents
    uint blockCount;
   }

   struct GenesisImport
   {
     bytes32 id; //referenced in the sidechain import tx
     address sender;
     address token;
     uint tokens;
   }


    address public miningContract;


    event ImportedTokens(address from, address token, uint tokens, uint nonce, bytes32 id);
    event ExportedTokens(address from, address token, uint tokens, uint nonce, bytes32 id);


   // 0xBTC is 0xb6ed7644c69416d67b522e20bc294a9a9b405b31;
  constructor(address mContract) public  {
    miningContract = mContract;

    //add genesis block
    blocks[0x0] = Block(0x0,0x0,0,totalBlockCount);

    totalBlockCount = totalBlockCount.add(1);
  }


  //do not allow ether to enter
  function() public payable {
      revert();
  }



  /*
    Authority to add blocks based on Proof of Work, EIP 918 and Mining Contract
  */

  function getMiningAuthority() public returns (address)
  {
    return EIP918Interface(miningContract).lastRewardTo();
  }

  function getMiningEpoch() public returns (uint)
  {
    return EIP918Interface(miningContract).epochCount();
  }


  function addNewBlock(

      bytes32 root, //new block hash
      bytes32 leaf, //previous block hash
      bytes32 proof //hash of all the new blocks tx, hash(tx1_hash,tx2_hash...txN_hash)

    )
      public
      returns (bool)
    {
      require(msg.sender == getMiningAuthority());
      require(blocks[leaf].root == leaf || leaf == 0x0); //must build off of an existing block OR the genesis block
      require(lastBlockMiningEpoch <  getMiningEpoch()); //one new sidechain block per Mining Round

      bytes32[] memory proof_array;
      proof_array[0] = proof;

      bytes32 computedHash =  _getMerkleRoot(leaf,proof_array);

      require(computedHash == root);



      bytes32 nextParentRoot = leaf;

      Block memory parent = blocks[nextParentRoot];


      uint thisBlockDepth = parent.depth.add(1);

       if( thisBlockDepth > deepestDepth )
      {
        deepestDepth = thisBlockDepth;
      }


      blocks[root] = Block(root,leaf,thisBlockDepth,totalBlockCount);

      totalBlockCount = totalBlockCount.add(1);

      return true;
    }




    function _getMerkleRoot (
      bytes32 leaf,
      bytes32[] proof
     ) internal pure returns (bytes32)
     {

       bytes32 computedHash = leaf;

       for (uint256 i = 0; i < proof.length; i++) {
         bytes32 proofElement = proof[i];

         if (computedHash < proofElement) {
           computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
         } else {
           computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
         }
       }

       return computedHash;

     }


     function burnTokens(address from, uint tokens ) public returns (bool)
     {
       address burnAddress = 0x0;

       require(  ERC20Interface(miningContract).transferFrom(from, burnAddress, tokens ) );

       burnedTokens[from] = burnedTokens[from].add(tokens);

       return true;
     }



    //import tokens
    // This makes a new 'genesis import' hash .... saved in contract.
    // Similar to a coinbase tx for the sidechain -- new tokens enter supply
    function importTokensToSidechain(address from,address token, uint tokens, uint nonce) public returns (bool)
    {


      bytes32 id = keccak256(abi.encodePacked( from, token, tokens, this, nonce ));

      require( imports[id].id == 0); //uuid must not already exist

      imports[id] = GenesisImport(id, from, token, tokens);

      require(  ERC20Interface(token).transferFrom(from, this, tokens ) );

      emit ImportedTokens( from, token, tokens, nonce, id );

      return true;
    }





    //Export tokens from the sidechain to mainnet
    function exportTokensFromSidechain(
      bytes32 branchHeadRoot,
      bytes32[] branchProof, //prove that the 'root' is part of the 'branch head root', just all the roots of the blocks between

      bytes32 root, //hash of the block containing the exit transaction
      bytes32 leaf, //exit transaction
      bytes32[] proof, //all other tx in this block (their hashes)

      address from,
      address token,
      uint tokens,
      uint nonce // ?
    )
    {

      bytes32 exitTransactionHash = keccak256(abi.encodePacked('exit',this,from,token,tokens,nonce));//this is the 'hash' of a sidechain TX
      require( leaf == exitTransactionHash);

      //must not have exported this leaf before
      require(validatedExitTransactions[leaf] != true);



      //prove that the 'root' is part of the 'branch head root' (no way to compute branchProof to fit)
      require(_getMerkleRoot(root,branchProof) == branchHeadRoot);

      //prove that the transaction is part of the root block (no way to compute proof to fit)
      require(_getMerkleRoot(leaf,proof) == root);


      require(_validateQualityConsensus(branchHeadRoot, root));




      validatedExitTransactions[leaf] = true;
      require( ERC20Interface(token).transfer(from, tokens ) );

      emit ExportedTokens( from, token, tokens, nonce, exitTransactionHash );


    }

    //requires that the head block ultimately built on top of the tail block
    //requires that there is REQUIRED_CONFIRMATION_BLOCKS of blocks in between
    //requires that there was high quality consensus (>90%) over that confirmation segment
    function _validateQualityConsensus(bytes32 headRoot, bytes32 tailRoot) public returns (bool)
    {

      //require that the segment is exactly REQUIRED_CONFIRMATION_BLOCKS blocks long
      require(blocks[tailRoot].depth == blocks[headRoot].depth.sub(REQUIRED_CONFIRMATION_BLOCKS)); // at least 256 confirms
      require(blocks[tailRoot].depth > 0);

      //require that the exit transaction is relatively recent, this just allows them to expire
      require(deepestDepth < REQUIRED_DEPTH_BLOCKS || blocks[tailRoot].depth > deepestDepth.sub(REQUIRED_DEPTH_BLOCKS));


      //make sure the branch segment of the confirms (tail to head) had better than 90% consensus
      uint blockCountDifference = blocks[headRoot].blockCount.sub( blocks[tailRoot].blockCount );
      uint blockDepthDifference = blocks[headRoot].depth.sub( blocks[tailRoot].depth );

      //block count across the branch span must be less than 110% of the depth across it!
      uint blockCountDifferenceLimit = blockDepthDifference.mul(110).div(100);
      require( blockCountDifference < blockCountDifferenceLimit );

      return true;

    }



    /*

    PROBLEM: A contentious 51% attacker can make new 'exit' tx with no parents/history and steal tokens
    ...perhaps use UTXO and prove them on each new block added ? ...prove them on exit ?


    User must provide a root for a head-block of a branch which has a depth
    equal to the 'deepestDepth'  global.   We compute its depth to make sure.
    Then,   Require a UTXO proof that there is a withdrawl tx in a block
    under that heads sidechain branch which has at least REQUIRED_CONFIRMATION_BLOCKS confirms.
    the UTXO must begin at the import UTXO hash.
    */
    //still  a WIP

    //1) How do we ensure that the exit tx does not make the users sidechain balance go to 0 ?

   //A) What if we had a 'checkpoint hash' that represented everyones balance !
    // Then a whistleblower can show that a TX would make someones balance go negative




}
