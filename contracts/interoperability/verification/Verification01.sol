// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import "../../interfaces/interoperability/ISilvaValidation.sol";
import {MerkleTree} from "../../utils/MerkleTree.sol";
import {Borsh} from "../../utils/borsh/Borsh.sol";
import {SilvaChainLib} from "../../libraries/SilvaChainLib.sol";
import {RLPReader} from "../../utils/rlp/RLPReader.sol";
import {PacketLib} from "../../libraries/PacketLib.sol";

library Verification01Lib{
    using SilvaChainLib for Borsh.Data;
    using MerkleTree for Borsh.Data;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    struct TxProof{
        SilvaChainLib.SilvaProof silvaProof;
        MerkleTree.LogPath txPath;
    }

    function decodeTxProof(
        Borsh.Data memory data
    ) internal pure returns (TxProof memory proof) {
        proof.silvaProof = data.decodeSilvaProof();
        proof.txPath = data.decodeLogPath();
    }
}


contract Verification01 is ISilvaVerification{
    using Verification01Lib for Borsh.Data;
    using Borsh for Borsh.Data;
    using SilvaChainLib for SilvaChainLib.SilvaProof;
    using MerkleTree for MerkleTree.MPTPath;
    using MerkleTree for MerkleTree.MerklePath;
    using MerkleTree for Borsh.Data;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    

    bytes32 public immutable PACKAGESIG = 0x00a622587bc83c620fbf1b9e15e002b83f5d716515ef8177e8cf88cc50e2453e;

    function verifyReceipt(bytes32 _root, uint sizeOfSrcAddress, bytes calldata _proof) external pure override returns(PacketLib.Packet memory packet){
        Borsh.Data memory data = Borsh.from(_proof);
        MerkleTree.LogPath memory txPath = data.decodeLogPath();
        data.done();

        bytes memory packetBytes = txPath.mptPath.validateMPTProof(_root);

        packet = _getPacket(packetBytes, txPath.logIndex, sizeOfSrcAddress);
    }

    function _getPacket(bytes memory itemBytes,uint index, uint sizeOfSrcAddress)internal pure returns (PacketLib.Packet memory packet) {
        RLPReader.RLPItem memory logItem = RLPReader.toRlpItem(itemBytes).safeGetItemByIndex(3);
        RLPReader.Iterator memory it = logItem
            .safeGetItemByIndex(index)
            .iterator();
        // TODO: assembly
        SilvaChainLib.Log memory log;
        log.ContractAddress = keccak256(
            abi.encodePacked(address(uint160(it.next().toUint())))
        );
        log.topicSig = bytes32(it.next().safeGetItemByIndex(0).toUint());
        log.data = it.next().toBytes();

        require(sizeOfSrcAddress > 0, "WRONG_ADDRESS_SIZE");
        require(log.topicSig == PACKAGESIG, "UNRECOGNIZE_LOG");

        packet = PacketLib.getPacket(
            log.data,
            sizeOfSrcAddress,
            log.ContractAddress
        );
        
    }
}