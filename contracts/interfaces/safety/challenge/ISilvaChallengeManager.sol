// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {ChallengeLib} from "../../../libraries/ChallengeLib.sol";

interface ISilvaChallengeManager {


struct Dispute {
        uint16 chainId;
        uint64 challengeStart;
        uint64 challengeEnd;
        bytes32[] headerStates;
        bytes32 extra;
    }

    event Published(
        uint64 indexed challengeIndex,
        uint64 indexed challengeSeq,
        uint32 step,
        address reactor,
        uint deadline,
        Dispute dispute
    );

    event ChallengeEnded(uint64 indexed challengeIndex);

    function createChallenge(
        uint16 chainId,
        address[2] memory participants,
        address settleAddress,
        ChallengeLib.Segment[2] memory segments
    ) external returns (uint64);

    function getChallenge(uint64 challengeIndex) external view returns(ChallengeLib.Challenge memory);

    function getPlayers(uint64 challengeIndex) external view returns(address referee, address attester);

    function getChallengeStep(uint64 challengeIndex) external view returns(uint32 step);
}
