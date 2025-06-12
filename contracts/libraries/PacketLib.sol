// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {Buffer} from "../utils/Buffer.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {RLPReader} from "../utils/rlp/RLPReader.sol";

library PacketLib {
    using Buffer for Buffer.buffer;
    using SafeMath for uint;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;

    struct Packet {
        bytes32 relayerId;
        uint16 srcChainId;
        uint16 dstChainId;
        uint64 nonce;
        address dstAddress;
        bytes srcAddress;
        bytes32 silvaAddress;
        bytes payload;
    }

    function getPacket(
        bytes memory data,
        uint sizeOfSrcAddress,
        bytes32 srcSilvaAddress
    ) internal pure returns (Packet memory) {
        // data def: abi.encodePacked(relayerId, nonce, srcChain, srcAddress, dstChain, dstAddress, payload);
        //              if from EVM
        // 0 - 31       0 - 31          |  total bytes size
        // 32 - 63      32 - 63         |  relayerId
        // 64 - 71      64 - 71         |  nonce
        // 72 - 73      72 - 73         |  srcChainId
        // 74 - P       74 - 93         |  srcAddress, where P = 41 + sizeOfSrcAddress,
        // P+1 - P+2    94 - 95         |  dstChainId
        // P+3 - P+22   96 - 115        |  dstAddress
        // P+23 - END   116 - END       |  payload

        // decode the packet
        uint256 realSize = data.length;
        uint nonPayloadSize = sizeOfSrcAddress.add(64); // 32 + 2 + 2 + 8 + 20, 64 + 20 = 84 if sizeOfSrcAddress == 20
        require(realSize >= nonPayloadSize, "Silva: invalid packet");
        uint payloadSize = realSize - nonPayloadSize;
        bytes32 relayerId;
        uint64 nonce;
        uint16 srcChain;
        uint16 dstChain;
        address dstAddress;
        assembly {
            relayerId:=mload(add(data,32))
            nonce := mload(add(data, 40))
            srcChain := mload(add(data, 42))
            dstChain := mload(add(data, add(44, sizeOfSrcAddress)))
            dstAddress := mload(add(data, add(64, sizeOfSrcAddress)))
        }

        require(srcChain != 0, "Silva: invalid packet");

        Buffer.buffer memory srcAddressBuffer;
        srcAddressBuffer.init(sizeOfSrcAddress);
        srcAddressBuffer.writeRawBytes(0, data, 74, sizeOfSrcAddress);

        Buffer.buffer memory payloadBuffer;
        if (payloadSize > 0) {
            payloadBuffer.init(payloadSize);
            payloadBuffer.writeRawBytes(
                0,
                data,
                nonPayloadSize.add(32),
                payloadSize
            );
        }

        return
            Packet(
                relayerId,
                srcChain,
                dstChain,
                nonce,
                dstAddress,
                srcAddressBuffer.buf,
                srcSilvaAddress,
                payloadBuffer.buf
            );
    }
}
