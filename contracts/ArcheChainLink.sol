pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/AggregatorV3Interface.sol";
/**
 * @notice  In order to ensure the authority of the contract,
 * this contract has introduced Ownable.sol provided by Openzeppelin,
 * please do not introduce it again in your own contract,
 * otherwise an error message will be returned
 */

contract ArcheChainLink is AggregatorV3Interface, Ownable {

    struct Phase {
        uint16 id;
        AggregatorV3Interface aggregator;
    }

    Phase private currentPhase;
    AggregatorV3Interface public proposedAggregator;
    mapping(uint16 => AggregatorV3Interface) public phaseAggregators;

    uint256 constant private PHASE_OFFSET = 64;
    uint256 constant private PHASE_SIZE = 16;
    uint256 constant private MAX_ID = 2 ** (PHASE_OFFSET + PHASE_SIZE) - 1;

    constructor(address _aggregator){
        setAggregator(_aggregator);
    }

    /**
     * @notice get data about a round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @param _roundId the requested round ID as presented through the proxy, this
     * is made up of the aggregator's round ID with the phase ID encoded in the
     * two highest order bytes
     * @return roundId is the round ID from the aggregator for which the data was
     * retrieved combined with an phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function getRoundData(uint80 _roundId) public view virtual override returns (
        uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        (uint16 phaseIds, uint64 aggregatorRoundId) = parseIds(_roundId);
        (
        roundId,
        answer,
        startedAt,
        updatedAt,
        answeredInRound
        ) = phaseAggregators[phaseIds].getRoundData(aggregatorRoundId);

        return addPhaseIds(roundId, answer, startedAt, updatedAt, answeredInRound, phaseIds);
    }

    /**
     * @notice get data about the latest round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @return roundId is the round ID from the aggregator for which the data was
     * retrieved combined with an phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function latestRoundData() public view virtual override returns (
        uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        Phase memory current = currentPhase;
        // cache storage reads
        (
        roundId,
        answer,
        startedAt,
        updatedAt,
        answeredInRound
        ) = current.aggregator.latestRoundData();

        return addPhaseIds(roundId, answer, startedAt, updatedAt, answeredInRound, current.id);
    }

    /**
     * @notice Used if an aggregator contract has been proposed.
     * @param _roundId the round ID to retrieve the round data for
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
    */
    function proposedGetRoundData(uint80 _roundId) public view virtual hasProposal() returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        return proposedAggregator.getRoundData(_roundId);
    }

    /**
     * @notice Used if an aggregator contract has been proposed.
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
    */
    function proposedLatestRoundData() public view virtual hasProposal() returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound){
        return proposedAggregator.latestRoundData();
    }

    /**
     * @notice returns the current phase's aggregator address.
     */
    function aggregator() external view returns (address){
        return address(currentPhase.aggregator);
    }

    /**
     * @notice returns the current phase's ID.
     */
    function phaseId() external view returns (uint16){
        return currentPhase.id;
    }

    /**
     * @notice represents the number of decimals the aggregator responses represent.
     */
    function decimals() external view override returns (uint8){
        return currentPhase.aggregator.decimals();
    }

    /**
     * @notice the version number representing the type of aggregator the proxy
     * points to.
     */
    function version() external view override returns (uint256){
        return currentPhase.aggregator.version();
    }

    /**
     * @notice returns the description of the aggregator the proxy points to.
     */
    function description() external view override returns (string memory){
        return currentPhase.aggregator.description();
    }

    /**
     * @notice Allows the owner to propose a new address for the aggregator
     * @param _aggregator The new address for the aggregator contract
     */
    function proposeAggregator(address _aggregator) external onlyOwner() {
        proposedAggregator = AggregatorV3Interface(_aggregator);
    }

    /**
     * @notice Allows the owner to confirm and change the address
     * to the proposed aggregator
     * @dev Reverts if the given address doesn't match what was previously
     * proposed
     * @param _aggregator The new address for the aggregator contract
     */
    function confirmAggregator(address _aggregator) external onlyOwner() {
        require(_aggregator == address(proposedAggregator), "Invalid proposed aggregator");
        delete proposedAggregator;
        setAggregator(_aggregator);
    }


    /*
     * Internal
     */

    function setAggregator(address _aggregator) internal {
        uint16 id = currentPhase.id + 1;
        currentPhase = Phase(id, AggregatorV3Interface(_aggregator));
        phaseAggregators[id] = AggregatorV3Interface(_aggregator);
    }

    function addPhase(uint16 _phase, uint64 _originalId) internal pure returns (uint80){
        return uint80(uint256(_phase) << PHASE_OFFSET | _originalId);
    }

    function parseIds(uint256 _roundId) internal pure returns (uint16, uint64){
        uint16 phaseIds = uint16(_roundId >> PHASE_OFFSET);
        uint64 aggregatorRoundId = uint64(_roundId);
        return (phaseIds, aggregatorRoundId);
    }

    function addPhaseIds(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound, uint16 phaseIds) internal pure returns (uint80, int256, uint256, uint256, uint80){
        return (
        addPhase(phaseIds, uint64(roundId)),
        answer,
        startedAt,
        updatedAt,
        addPhase(phaseIds, uint64(answeredInRound))
        );
    }

    /*
     * Modifiers
     */

    modifier hasProposal() {
        require(address(proposedAggregator) != address(0), "No proposed aggregator present");
        _;
    }

}

