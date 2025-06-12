// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {Borsh} from "../../utils/borsh/Borsh.sol";
import {RLPWriter} from "../../utils/rlp/RLPWriter.sol";

library EVMHeaderLib {
    using Borsh for Borsh.Data;
    using EVMHeaderLib for Borsh.Data;
    using EVMHeaderLib for EVMHeader;

    struct EVMHeader {
        bytes32 parentHash;
        bytes32 uncleHash;
        address coinbase;
        bytes32 stateRoot;
        bytes32 transactionsRoot;
        bytes32 receiptsRoot; //expectedHash
        bytes logsBloom; // 256 bytes
        uint256 difficulty; //bigint
        uint256 number; //bigint
        uint256 gasLimit;
        uint256 gasUsed;
        uint256 timestamp;
        bytes extraData; //
        bytes32 mixHash;
        bytes8 nonce;
        Field[] extraFileds;  // further upgrading field
    }

    // uint8
    enum Type{
        BOOLEAN,
        UINT256,
        STRING,
        ADDRESS,
        BYTES,
        BYTES32
    }

    // upgrade filed in header
    struct Field{
        Type ftype;
        bytes value; 
    }

    function decodeField(Borsh.Data memory data)internal pure returns (Field memory field) {
        field.ftype = Type(data.decodeU8());
        field.value = data.decodeBytes();
    }

    function decodeEVMHeader(
        Borsh.Data memory data
    ) internal pure returns (EVMHeader memory header) {
        header.parentHash = data.decodeBytes32();
        header.uncleHash = data.decodeBytes32();
        header.coinbase = address(data.decodeBytes20());
        header.stateRoot = data.decodeBytes32();
        header.transactionsRoot = data.decodeBytes32();
        header.receiptsRoot = data.decodeBytes32();
        header.logsBloom = data.decodeBytesFixedLength(256);
        header.difficulty = data.decodeU256();
        header.number = data.decodeU256();
        header.gasLimit = data.decodeU256();
        header.gasUsed = data.decodeU256();
        header.timestamp = data.decodeU256();
        header.extraData = data.decodeBytes();
        header.mixHash = data.decodeBytes32();
        header.nonce = data.decodeBytes8();
        uint num = data.decodeU32();
        header.extraFileds = new Field[](num);
        for (uint i = 0; i < num; i++) {
            header.extraFileds[i] = data.decodeField();
        }
    }

    function rlpEVMHeaderHash(
        EVMHeader memory header
    ) internal pure returns (bytes32) {
        bytes[] memory raw = new bytes[](15 + header.extraFileds.length);
        raw[0] = RLPWriter.writeBytes(abi.encodePacked(header.parentHash));
        raw[1] = RLPWriter.writeBytes(abi.encodePacked(header.uncleHash));
        raw[2] = RLPWriter.writeAddress(header.coinbase);
        raw[3] = RLPWriter.writeBytes(abi.encodePacked(header.stateRoot));
        raw[4] = RLPWriter.writeBytes(abi.encodePacked(header.transactionsRoot));
        raw[5] = RLPWriter.writeBytes(abi.encodePacked(header.receiptsRoot));
        raw[6] = RLPWriter.writeBytes(header.logsBloom);
        raw[7] = RLPWriter.writeUint(header.difficulty);
        raw[8] = RLPWriter.writeUint(header.number);
        raw[9] = RLPWriter.writeUint(header.gasLimit);
        raw[10] = RLPWriter.writeUint(header.gasUsed);
        raw[11] = RLPWriter.writeUint(header.timestamp);
        raw[12] = RLPWriter.writeBytes(header.extraData);
        raw[13] = RLPWriter.writeBytes(abi.encodePacked(header.mixHash));
        raw[14] = RLPWriter.writeBytes(abi.encodePacked(header.nonce));
        for (uint i = 0; i < header.extraFileds.length; i++) {
            raw[15 + i] = _writeTypeToBytes(header.extraFileds[i]);
        }
        return keccak256(RLPWriter.writeList(raw));
    }

    function _writeTypeToBytes(
        Field memory field
    ) internal pure returns (bytes memory raw) {
        if (field.ftype == Type.BOOLEAN) {
            bool v = abi.decode(field.value, (bool));
            raw = RLPWriter.writeBool(v);
        } else if (field.ftype == Type.UINT256) {
            uint256 v = abi.decode(field.value, (uint256));
            raw = RLPWriter.writeUint(v);
        } else if (field.ftype == Type.STRING) {
            string memory v = abi.decode(field.value, (string));
            raw = RLPWriter.writeString(v);
        } else if (field.ftype == Type.ADDRESS) {
            address v = abi.decode(field.value, (address));
            raw = RLPWriter.writeAddress(v);
        } else if (field.ftype == Type.BYTES) {
            bytes memory v = abi.decode(field.value, (bytes));
            raw = RLPWriter.writeBytes(v);
        } else if (field.ftype == Type.BYTES32) {
            bytes32 v = abi.decode(field.value, (bytes32));
            raw = RLPWriter.writeBytes(abi.encodePacked(v));
        }
    }
}
