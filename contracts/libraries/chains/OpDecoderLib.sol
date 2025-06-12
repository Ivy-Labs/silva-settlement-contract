// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {EVMHeaderLib} from "./EVMHeaderLib.sol";
import {Borsh} from "../../utils/borsh/Borsh.sol";
import {RLPReader} from "../../utils/rlp/RLPReader.sol";

library OpDecoderLib{
    using Borsh for Borsh.Data;
    using EVMHeaderLib for Borsh.Data;
    using EVMHeaderLib for EVMHeaderLib.EVMHeader;
    using OpDecoderLib for Borsh.Data;
    using OpDecoderLib for Output;
    using RLPReader for RLPReader.RLPItem;

    // rollup contract: 0xdfe97868233d1aa22e815a266982f2cf17685a27;
    // storage: (slot: 3, storageKey: 0xc2575a0e9e593c00f959f8c92f12db2869c3395a3b0502d05e2516446f71f85b)
    struct Output{
        uint64 index;  // 
        uint128 l2BlockNumber;
        uint128 timestamp;
        bytes32 version;
        bytes32 stateRoot;  // rollup header state root
        bytes32 storageRoot;  // rollup header storage root for contract: 0x4200000000000000000000000000000000000016
        bytes32 hash;  // rollup header hash
    }

    function decodeOutput(Borsh.Data memory data) internal pure returns (Output memory output) {
        output.index = data.decodeU64();
        output.l2BlockNumber = data.decodeU128();
        output.timestamp = data.decodeU128();
        output.version = data.decodeBytes32();
        output.stateRoot = data.decodeBytes32();
        output.storageRoot = data.decodeBytes32();
        output.hash = data.decodeBytes32();
    }

    // only for validation
    function outputHash(Output memory output) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(output.version, output.stateRoot, output.storageRoot, output.hash));
    }

    function opHeaderStateHash(EVMHeaderLib.EVMHeader memory header) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(header.receiptsRoot, header.rlpEVMHeaderHash()));
    }

    struct OutputProposal{
        bytes32 outputRoot;
        uint128 timestamp;
        uint128 l2BlockNumber;
    }

    function decodeOutputProposal(Borsh.Data memory data) internal pure returns (OutputProposal memory output) {
        output.outputRoot = data.decodeBytes32();
        output.timestamp = data.decodeU128();
        output.l2BlockNumber = data.decodeU128();
    }
}