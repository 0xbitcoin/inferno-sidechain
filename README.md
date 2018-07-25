# inferno-sidechain
An Ethereum Sidechain using Signed Lava Packets, MerkleProofs, and POWRR

A Signed Lava Packet is simple an offchain signed transaction, designating that X tokens should be transferred to a particular address

POWRR: Proof of Work Round Robin, established by a MiningKing contract which assigns new authoritative kings based on Proof of Work



1. Basic Concepts

  * Consider a lava packet 'mined' if it exists a a leaf inside of a 'mined' merkle root



2. Withdrawing/Unlocking

  A.  To begin,  one must make a 'lava sidechain' tx which is a lava packet in which:  
    1.  The WalletAddress and  To  fields are BOTH   the address of the 'sidechain contract' (this)
    2. This sidechain TX must be mined by the king   (one confirm needed only?)


By definition, the 'correct' sidechain is the sidechain fork (since it CAN fork) with the MOST proof of work put into it.  And it must be proven to be the one with the most work put into it.  



//collation headers get verified and processed 
Thought 1:  The smart contract ENFORCES that the root state hash MUCH always be correct !!  It doesnt let the king set it to whatever - the king can only pass in an array of TX signatures




Gas cost:
20K for a tx
30 gas per keccak



 TODO

Experimentation with Merkle Proofs
