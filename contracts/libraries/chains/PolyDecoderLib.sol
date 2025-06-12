// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
import {Borsh} from "../../utils/borsh/Borsh.sol";
import {MerkleTree} from "../../utils/MerkleTree.sol";
import {EVMHeaderLib} from "./EVMHeaderLib.sol"; 
import {RLPReader} from "../../utils/rlp/RLPReader.sol";

library PolyDecoderLib {
    using Borsh for Borsh.Data;
    using PolyDecoderLib for Borsh.Data;
    using MerkleTree for Borsh.Data;
    using MerkleTree for MerkleTree.MPTPath;
    using MerkleTree for MerkleTree.MerklePath;
    using EVMHeaderLib for Borsh.Data;
    using EVMHeaderLib for EVMHeaderLib.EVMHeader;
    using RLPReader for RLPReader.RLPItem;


    function polyHeaderState(EVMHeaderLib.EVMHeader memory header) internal pure returns(bytes32 hash){
        hash = keccak256(abi.encodePacked(header.receiptsRoot, header.rlpEVMHeaderHash()));
    }

    struct HeaderBlock {
        bytes32 root;
        uint256 start;
        uint256 end;
        uint256 createdAt;
        address proposer;
    }

    struct PolyRollupProofOnETH{
        uint blockId;
        MerkleTree.MerklePath path;
    }

    function decodePolyRollupProofOnETH(Borsh.Data memory data) internal pure returns (PolyRollupProofOnETH memory proof) {
        proof.blockId = data.decodeU256();
        proof.path = data.decodeMerklePath();
    }
}