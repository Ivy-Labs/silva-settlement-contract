// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {Borsh} from "../../utils/borsh/Borsh.sol";
import {MerkleTree} from "../../utils/MerkleTree.sol";
import {RLPWriter} from "../../utils/rlp/RLPWriter.sol";
import {SilvaChainLib} from "../SilvaChainLib.sol";
import {EVMHeaderLib} from "./EVMHeaderLib.sol";

library BscDecoderLib {
    using Borsh for Borsh.Data;
    using EVMHeaderLib for Borsh.Data;
    using EVMHeaderLib for EVMHeaderLib.EVMHeader;
    using BscDecoderLib for Borsh.Data;
    using BscDecoderLib for BscDecoderLib.BscHeader;
    using BscDecoderLib for BscDecoderLib.Vote;
    using SilvaChainLib for Borsh.Data;

    struct VoteData {
        uint64 sourceNumber;
        bytes32 sourceHash;
        uint64 targetNumber;
        bytes32 targetHash;
    }

    function decodeBscVoteData(
        Borsh.Data memory data
    ) internal pure returns (VoteData memory voteData) {
        voteData.sourceNumber = data.decodeU64();
        voteData.sourceHash = data.decodeBytes32();
        voteData.targetNumber = data.decodeU64();
        voteData.targetHash = data.decodeBytes32();
    }

    function rlpVoteDataHash(
        VoteData memory voteData
    ) internal pure returns (bytes32 hash) {
        bytes[] memory raw = new bytes[](4);
        raw[0] = RLPWriter.writeUint(uint256(voteData.sourceNumber));
        raw[1] = RLPWriter.writeBytes(abi.encodePacked(voteData.sourceHash));
        raw[2] = RLPWriter.writeUint(uint256(voteData.targetNumber));
        raw[3] = RLPWriter.writeBytes(abi.encodePacked(voteData.targetHash));
        return keccak256(RLPWriter.writeList(raw));
    }

    struct Vote {
        VoteData data;
        // BLS aggregated signature, 96-bytes
        bytes signature;
        uint64 validatorsBitSet;
        bytes32 validatorsHash;  // keccak256(abi.encodePacked(validators[]));

        bytes aggreatedPK; // BLS aggregated public key, 48
    }

    function voteHash(Vote memory vote) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(vote.data.sourceNumber, vote.data.sourceHash, vote.data.targetNumber, vote.data.targetHash, vote.signature, vote.validatorsBitSet, vote.validatorsHash));
    }

    function decodeBscVote(
        Borsh.Data memory data
    ) internal pure returns (Vote memory vote) {
        vote.data = data.decodeBscVoteData();
        vote.signature = data.decodeBytes96();
        vote.validatorsBitSet = data.decodeU64();
        vote.validatorsHash = data.decodeBytes32();
        vote.aggreatedPK = data.decodeBytes48();
    }

    struct VoteWithVoter{
        Attestation atts;
        bytes[] validators;
    }

    function validatorsHash(bytes[] memory validators) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encode(validators));
    }

    function decodeVoteWithVoter(Borsh.Data memory data) internal pure returns (VoteWithVoter memory voteWithVoter) {
        voteWithVoter.atts = data.decodeAttestation();
        uint len = data.decodeU32();
        for (uint i = 0; i < len; i++) {
            voteWithVoter.validators[i] = data.decodeBytes48();
        }
    }

    struct BscHeader {
        EVMHeaderLib.EVMHeader EVMHeader;
        bytes32 latestEpoch;
        bytes32 preEpoch;
        uint256 latestNums;
        uint256 preNums;
    }

    function decodeBscHeader(
        Borsh.Data memory data
    ) internal pure returns (BscHeader memory bscHeader) {
        bscHeader.EVMHeader = data.decodeEVMHeader();
        bscHeader.latestEpoch = data.decodeBytes32();
        bscHeader.preEpoch = data.decodeBytes32();
        bscHeader.latestNums = data.decodeU64();
        bscHeader.preNums = data.decodeU64();
    }

    function bscHeaderHash(
        BscHeader memory header
    ) internal pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encodePacked(
                header.EVMHeader.rlpEVMHeaderHash(),
                header.latestEpoch,
                header.preEpoch,
                header.latestNums,
                header.preNums
            )
        );
    }

    function bscHeaderState(
        BscHeader memory header
    ) internal pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encodePacked(
                header.EVMHeader.receiptsRoot,
                header.bscHeaderHash()
            )
        );
    }

    struct FinalityProof {
        BscHeader[] fHeaders;
        Attestation atts;
    }

    function decodeFinalityProof(
        Borsh.Data memory data
    ) internal pure returns (FinalityProof memory fProof) {
        uint length = data.decodeU32();
        fProof.fHeaders = new BscHeader[](length);
        for (uint i = 0; i < length; i++) {
            fProof.fHeaders[i] = data.decodeBscHeader();
        }
        fProof.atts = data.decodeAttestation();
    }

    function validateFinality(BscHeader memory current, BscHeader memory previous, FinalityProof memory fProof, uint64 epochLength) internal pure {
        uint256 slot = current.EVMHeader.number % epochLength;
        uint64 index = 0;
        bytes32 previousHash;
        do {
            previousHash = previous.EVMHeader.rlpEVMHeaderHash();
            require(previous.EVMHeader.number + 1 == current.EVMHeader.number, "WRONG_HEIGHT");
            require(previousHash == current.EVMHeader.parentHash, "WRONG_PARENT");
            if (slot != 0){
                require(previous.preEpoch == current.preEpoch && previous.latestEpoch == current.latestEpoch, "WRONG_EPOCH_VALIDATORS");
                require(previous.preNums == current.preNums && previous.latestNums == current.latestNums, "WRONG_VALIDATORS_NUMS");
            } else {
                (uint64 nums, bytes32 hash) = current.extractValidatorsHash();
                require(previous.latestEpoch == current.preEpoch && current.latestEpoch == hash, "WRONG_EPOCH_VALIDATORS");
                require(previous.latestNums == current.preNums && previous.latestNums == nums, "WRONG_VALIDATORS_NUMS");         
            }
           
            if (fProof.fHeaders.length > index) {
                previous = current;
                current = fProof.fHeaders[index];
                index++;
            } else {
                break;
            }
        } while(true);
        previousHash = current.EVMHeader.rlpEVMHeaderHash();
        // border
        uint256 border = current.preNums / 2;
        if (slot < border) {
            require(current.preEpoch == fProof.atts.justify.validatorsHash && current.preEpoch == fProof.atts.finall.validatorsHash, "");
        } else if (slot == border) {
            require(current.preEpoch == fProof.atts.justify.validatorsHash && current.latestEpoch == fProof.atts.finall.validatorsHash, "");
        } else {
            require(current.latestEpoch == fProof.atts.justify.validatorsHash && current.latestEpoch == fProof.atts.finall.validatorsHash, "");
        }
        require(previousHash == fProof.atts.justify.data.targetHash && previousHash == fProof.atts.finall.data.sourceHash &&
                current.EVMHeader.number == fProof.atts.justify.data.targetNumber && current.EVMHeader.number == fProof.atts.finall.data.sourceNumber,
                "WRONG_VOTE"
                );
    }

    struct Attestation {
        Vote justify;
        Vote finall;
    }

    function decodeAttestation(Borsh.Data memory data) internal pure returns (Attestation memory atts) {
        atts.justify = data.decodeBscVote();
        atts.finall = data.decodeBscVote();
    }

    function attestationHash(Attestation memory fProof) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(fProof.justify.voteHash(), fProof.finall.voteHash()));
    }

    function extractValidatorsHash(
        BscHeader memory header
    ) internal pure returns (uint64, bytes32) {
        // TODO:
        Borsh.Data memory borsh = Borsh.from(header.EVMHeader.extraData);

        borsh.skipSpecificLengthBytes(32);
        uint64 nums = uint64(borsh.decodeU8());
        bytes[] memory validators = new bytes[](nums);
        for (uint i = 0; i < nums; i++) {
            borsh.skipSpecificLengthBytes(20);
            validators[i] = borsh.decodeBytes48();
        }
        return (nums, validatorsHash(validators));
    }

    struct History {
        uint64 height;
        uint64 epochLength;
    }
}
