// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {ChallengeLib} from "../../libraries/ChallengeLib.sol";
import {SilvaChainLib} from "../../libraries/SilvaChainLib.sol";

interface ISilvaChain {
    function updateChainConfig(bytes memory _config) external;

    function validatePublish(
        uint32 step,
        ChallengeLib.ChallState memory state,
        bytes[] calldata publish,
        bytes calldata proof
    ) external view returns(ChallengeLib.Game memory game);

    function initRound()
        external
        view
        returns (ChallengeLib.Round memory round);

    function nextChallengeStep(
        uint32 disputeIndex,
        ChallengeLib.ChallState memory state,
        bytes[] calldata datas
    ) external view returns (ChallengeLib.Game memory game);
}
