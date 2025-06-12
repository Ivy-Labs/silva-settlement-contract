pragma solidity ^0.8;
import {MerkleTree} from "../MerkleTree.sol";

contract MerkleTreeTest {
    function ceilLog2(uint x) external pure returns (uint){
        return  MerkleTree.ceilLog2(x);
    }

    function computeRoot(MerkleTree.MerklePath memory proof, bytes32 leaf) external pure returns (bytes32 hash){
        return MerkleTree.computeRoot(proof, leaf);
    }

    function computeRootSha256(MerkleTree.MerklePath memory proof, bytes32 leaf) external pure returns (bytes32 hash){
        return MerkleTree.computeRootSha256(proof, leaf);
    }

    function buildMerkleTree(bytes32[] memory leaves) external pure returns (bytes32){
        return MerkleTree.buildMerkleTree(leaves);
    }

    function buildMerkleTreeSha256(bytes32[] memory leaves) external pure returns (bytes32){
        return MerkleTree.buildMerkleTreeSha256(leaves);
    }

    function validateMPTProof(MerkleTree.MPTPath memory path, bytes32 root) external pure returns (bytes memory){
        return MerkleTree.validateMPTProof(path, root);
    }

    function validateMPTPProofWithKey(MerkleTree.MPTPath memory path, bytes32 root) external pure returns (bytes memory, bytes32){
        return MerkleTree.validateMPTPProofWithKey(path, root);
    }

} 