// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUnderwriterPolicy} from "../interfaces/IUnderwriterPolicy.sol";
import {FHE, euint64, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title SimpleUnderwriterPolicy
/// @notice Simple FHE-based insurance policy for testing
/// @dev Returns fixed risk scores and validates disputes
contract SimpleUnderwriterPolicy is IUnderwriterPolicy, ERC165 {
    struct PolicyConfig {
        uint64 baseRiskScore;
        bool configured;
    }

    mapping(uint256 => PolicyConfig) public policies;

    event PolicySet(uint256 indexed coverageId, uint64 baseRiskScore);

    error PolicyAlreadySet();

    /// @inheritdoc IUnderwriterPolicy
    function onPolicySet(uint256 coverageId, bytes calldata data) external {
        if (policies[coverageId].configured) revert PolicyAlreadySet();
        
        uint64 baseRiskScore = abi.decode(data, (uint64));
        require(baseRiskScore <= 10000, "Risk score must be <= 10000 bps");
        
        policies[coverageId] = PolicyConfig({
            baseRiskScore: baseRiskScore,
            configured: true
        });
        
        emit PolicySet(coverageId, baseRiskScore);
    }

    /// @inheritdoc IUnderwriterPolicy
    function evaluateRisk(uint256 coverageId, bytes calldata) external returns (euint64 riskScore) {
        require(policies[coverageId].configured, "Policy not configured");
        
        uint64 score = policies[coverageId].baseRiskScore;
        euint64 encrypted = FHE.asEuint64(score);
        
        FHE.allowThis(encrypted);
        FHE.allow(encrypted, msg.sender);
        
        return encrypted;
    }

    /// @inheritdoc IUnderwriterPolicy
    function judge(uint256 coverageId, bytes calldata disputeProof) external returns (ebool valid) {
        require(policies[coverageId].configured, "Policy not configured");
        
        // Simple validation: decode proof and check if valid
        (bool isValid, uint256 timestamp) = abi.decode(disputeProof, (bool, uint256));
        
        // Check if dispute is recent (within 30 days)
        bool result = isValid && (block.timestamp - timestamp <= 30 days);
        
        ebool encrypted = FHE.asEbool(result);
        FHE.allowThis(encrypted);
        FHE.allow(encrypted, msg.sender);
        
        return encrypted;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IUnderwriterPolicy).interfaceId || super.supportsInterface(interfaceId);
    }
}
