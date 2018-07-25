var MerkleProof = artifacts.require("./MerkleProof.sol");

import MerkleTree from "./helpers/MerkleTree.js";
import { sha3, bufferToHex } from "ethereumjs-util";



/*
We will run a test in which an inferno sidechain contract 'I' exists.
A designated 'king' will be able to on-chain submit RootHashes to the contract, which compose leaves (the leaves are lava packets)

Every 'user' will need to keep track of their own 'branch' which will include all lava packets that are either TO or FROM them. (personal ledger)


1. how to prevent one lava packet from being a leaf in multiple root hashes (does this matter?)

*/



contract('InfernoSidechains', function(accounts) {
  let merkleProof;

  before(async function() {
    merkleProof = await MerkleProof.new();
  });

  describe("verifyProof", function() {
    it("should return true for a valid Merkle proof", async function() {
      const elements = ["a", "b", "c", "d"];
      const merkleTree = new MerkleTree(elements);

      const root = merkleTree.getHexRoot();

      const proof = merkleTree.getHexProof(elements[0]);

      const leaf = bufferToHex(sha3(elements[0]));

      const result = await merkleProof.verifyProof(proof, root, leaf);
      assert.isOk(result, "verifyProof did not return true for a valid proof");
    });

    it("should return false for an invalid Merkle proof", async function() {
      const correctElements = ["a", "b", "c"]
      const correctMerkleTree = new MerkleTree(correctElements);

      const correctRoot = correctMerkleTree.getHexRoot();

      const correctLeaf = bufferToHex(sha3(correctElements[0]));

      const badElements = ["d", "e", "f"]
      const badMerkleTree = new MerkleTree(badElements)

      const badProof = badMerkleTree.getHexProof(badElements[0])

      const result = await merkleProof.verifyProof(badProof, correctRoot, correctLeaf);
      assert.isNotOk(result, "verifyProof did not return false for an invalid proof");
    });

    it("should return false for a Merkle proof of invalid length", async function() {
      const elements = ["a", "b", "c"]
      const merkleTree = new MerkleTree(elements);

      const root = merkleTree.getHexRoot();

      const proof = merkleTree.getHexProof(elements[0]);
      const badProof = proof.slice(0, proof.length - 5);

      const leaf = bufferToHex(sha3(elements[0]));

      const result = await merkleProof.verifyProof(badProof, root, leaf);
      assert.isNotOk(result, "verifyProof did not return false for proof of invalid length");
    })
  });
});
