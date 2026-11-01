// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../governance/DecentralizationPhase.sol";

/**
 * @title TestDecentralizationPhase
 * @notice Same handover rules as DecentralizationPhase, with small milestone thresholds.
 * @dev Production PHASE1_* and PHASE2_* constants are unchanged. Only the internal readers differ.
 */
contract TestDecentralizationPhase is DecentralizationPhase {
    constructor(address hybridCouncil_, address daoTimelock_)
        DecentralizationPhase(hybridCouncil_, daoTimelock_)
    {}

    function _phase1MinDeliveries() internal pure override returns (uint32) {
        return 3;
    }

    function _phase1MinDrivers() internal pure override returns (uint16) {
        return 2;
    }

    function _phase1MinDays() internal pure override returns (uint32) {
        return 1;
    }

    function _phase1StabilityDays() internal pure override returns (uint16) {
        return 1;
    }

    function _phase2MinDeliveries() internal pure override returns (uint32) {
        return 6;
    }

    function _phase2MinDrivers() internal pure override returns (uint32) {
        return 3;
    }

    function _phase2MinGMV() internal pure override returns (uint64) {
        return 1000;
    }

    function _phase2StabilityDays() internal pure override returns (uint16) {
        return 1;
    }
}
