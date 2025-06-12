// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import "./MemoryUtils.sol";

library Borsh {
    using Borsh for Data;

    struct Data {
        uint ptr;
        uint end;
    }
    function from(bytes memory data) internal pure returns (Data memory res) {
        uint ptr;
        assembly {
            ptr := data
        }
        unchecked {
            res.ptr = ptr + 32;
            res.end = res.ptr + MemoryUtils.readMemory(ptr);
        }
    }

    // This function assumes that length is reasonably small, so that data.ptr + length will not overflow. In the current code, length is always less than 2^32.
    function requireSpace(Data memory data, uint length) internal pure {
        unchecked {
            require(data.ptr + length <= data.end, "Parse error: unexpected EOI");
        }
    }

    function read(Data memory data, uint length) internal pure returns (bytes32 res) {
        data.requireSpace(length);
        res = bytes32(MemoryUtils.readMemory(data.ptr));
        unchecked {
            data.ptr += length;
        }
        return res;
    }

    function done(Data memory data) internal pure {
        require(data.ptr == data.end, "Parse error: EOI expected");
    }

    // Same considerations as for requireSpace.
    function peekKeccak256(Data memory data, uint length) internal pure returns (bytes32) {
        data.requireSpace(length);
        return MemoryUtils.keccak256Raw(data.ptr, length);
    }

    // Same considerations as for requireSpace.
    function peekSha256(Data memory data, uint length) internal view returns (bytes32) {
        data.requireSpace(length);
        return MemoryUtils.sha256Raw(data.ptr, length);
    }

    function decodeU8(Data memory data) internal pure returns (uint8) {
        return uint8(bytes1(data.read(1)));
    }

    function decodeU16(Data memory data) internal pure returns (uint16) {
        return MemoryUtils.swapBytes2(uint16(bytes2(data.read(2))));
    }

    function decodeU32(Data memory data) internal pure returns (uint32) {
        return MemoryUtils.swapBytes4(uint32(bytes4(data.read(4))));
    }

    function decodeU64(Data memory data) internal pure returns (uint64) {
        return MemoryUtils.swapBytes8(uint64(bytes8(data.read(8))));
    }

    function decodeU128(Data memory data) internal pure returns (uint128) {
        return MemoryUtils.swapBytes16(uint128(bytes16(data.read(16))));
    }

    function decodeU256(Data memory data) internal pure returns (uint256) {
        return MemoryUtils.swapBytes32(uint256(data.read(32)));
    }

    function decodeBytes8(Data memory data) internal pure returns(bytes8){
        return bytes8(data.read(8));
    }

    function decodeBytes20(Data memory data) internal pure returns (bytes20) {
        return bytes20(data.read(20));
    }

    function decodeBytes32(Data memory data) internal pure returns (bytes32) {
        return data.read(32);
    }

    function decodeBool(Data memory data) internal pure returns (bool) {
        uint8 res = data.decodeU8();
        require(res <= 1, "Parse error: invalid bool");
        return res != 0;
    }

    function skipBytes(Data memory data) internal pure {
        uint length = data.decodeU32();
        data.requireSpace(length);
        unchecked {
            data.ptr += length;
        }
    }

    function skipSpecificLengthBytes(Data memory data,uint length) internal pure{
        data.requireSpace(length);
        unchecked {
            data.ptr += length;
        }
    }

    // BLS签名长度
    function decodeBytes96(Data memory data) internal pure returns(bytes memory res){
        return data.decodeBytesFixedLength(96);
    }
    // BLS公钥长度
    function decodeBytes48(Data memory data) internal pure returns(bytes memory res){
        return data.decodeBytesFixedLength(48);
    }

    function decodeBytesFixedLength(Data memory data,uint length) internal pure returns(bytes memory res){
        data.requireSpace(length);
        res=MemoryUtils.memoryToBytes(data.ptr, length);
        unchecked {
            data.ptr+=length;
        }
    }

    function decodeBytes(Data memory data) internal pure returns (bytes memory res) {
        uint length = data.decodeU32();
        data.requireSpace(length);
        res = MemoryUtils.memoryToBytes(data.ptr, length);
        unchecked {
            data.ptr += length;
        }
    }

    function copyBytes(Data memory data,uint length) internal pure returns (bytes memory res){
        // we don't update the data ptr, only copy from the ptr
        data.requireSpace(length);
        res=MemoryUtils.memoryToBytes(data.ptr, length);
    }

    function getPtr(Data memory data) internal pure returns (uint ptr) {
        ptr=data.ptr;
    }
    function setPtr(Data memory data,uint ptr) internal pure  {
        unchecked {
            data.ptr = ptr;
        }
    }
}
