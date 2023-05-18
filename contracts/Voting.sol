// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/** 
 * @title Proposal info & Voting Result Storage
 * @dev Contract module which provides a storage mechanism
 * that allows only owner to store proposal information &
 * voting result in the blockchain
*/
contract Voting is Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _proposalId;

    struct Proposal {
        uint256 timestamp;
        uint256 totalParticipants;
        string proposalInfo;
        string votingResult;
    }

    // Mapping from proposalID to proposal info
    mapping(uint256 => Proposal) private _proposals;

    /**
     * @dev Emitted when a new proposal along with result is added
    */
    event ProposalAdded(
        uint256 proposalId,
        uint256 timestamp,
        uint256 totalParticipants,
        string proposalInfo,
        string votingResult
    );

    constructor() {
        _proposalId.increment();
    }
    
    //---------------------------- EXTERNAL -------------------//

    /**
     * @notice Add proposal & voting result 
     * @dev only owner can call this function 
     * @param totalParticipants number of participants who voted
     * @param proposalInfo Link to proposal info
     * @param votingResult Link to voting result info
    */
    function addProposal( 
        uint256 totalParticipants,
        string memory proposalInfo,
        string memory votingResult
    ) 
        external 
        onlyOwner
        whenNotPaused
    {
        require(totalParticipants > 0, "REJUVE: Total participants cannot be zero");
        bytes memory propInfo = bytes(proposalInfo);
        require(propInfo.length != 0, "REJUVE: Proposal info cannot be empty");
        bytes memory voteResult = bytes(votingResult);
        require(voteResult.length != 0, "REJUVE: Voting result info cannot be empty");

        _addProposal(totalParticipants, proposalInfo, votingResult);
    }

    /**
     * @dev Triggers stopped state.
    */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    //-------------------- EXTERNAL VIEWS ------------------------//

    /**
     * @return Proposal and voting result information
    */
    function getProposal(
        uint256 proposalId
    ) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    //-------------------- PRIVATE -------------------------------//

    function _addProposal( 
        uint256 totalParticipants,
        string memory proposalInfo,
        string memory votingResult
    ) 
        private 
    {
        uint256 proposalID = _proposalId.current();
        _proposalId.increment();
        Proposal storage prop = _proposals[proposalID];
        prop.timestamp = block.timestamp;
        prop.totalParticipants = totalParticipants;
        prop.proposalInfo = proposalInfo;
        prop.votingResult = votingResult; 

        emit ProposalAdded(proposalID, block.timestamp, totalParticipants, proposalInfo, votingResult);  
    }
}