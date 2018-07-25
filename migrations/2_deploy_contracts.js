var _0xBitcoinToken = artifacts.require("./_0xBitcoinToken.sol");

var MiningKing = artifacts.require("./MiningKing.sol");

var MerkleProof = artifacts.require("./MerkleProof.sol");

var InfernoSidechain = artifacts.require("./InfernoSidechain.sol");

var ECRecovery = artifacts.require("./ECRecovery.sol");



var LavaWallet = artifacts.require("./LavaWallet.sol");

module.exports = function(deployer) {

  deployer.deploy(ECRecovery);

    deployer.link(ECRecovery, LavaWallet)

    deployer.deploy(MerkleProof);

  return deployer.deploy(_0xBitcoinToken).then(function(){
    console.log('deploy 1 ')
    return deployer.deploy(MintHelper, _0xBitcoinToken.address, 0, 0 ).then(function(){
        return deployer.deploy(MiningKing, _0xBitcoinToken.address).then(function(){
            console.log('deploy 2 ',  MiningKing.address)
          return deployer.deploy(LavaWallet, MiningKing.address).then(function(){
              console.log('deploy 3 ',  LavaWallet.address)
               return LavaWallet.deployed()
        });
      });
    });

  });

  //  deployer.deploy(miningKing);






};
