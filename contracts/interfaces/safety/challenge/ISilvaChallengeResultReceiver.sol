// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

interface ISilvaChallengeResultReceiver {
    function settleChallenge(
        uint64 challengeIndex,
        address winner,
        address loser,
        bool bothWin
    ) external;
}
