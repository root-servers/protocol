pragma solidity 0.5.17;

import {IGroup} from "contracts/src/common/interface/IGroup.sol";

contract IPolicyGroup is IGroup {
	function getVotingGroupIndex() external view returns (uint256);

	function incrementVotingGroupIndex() external;

	function voting(address _policy) external view returns (bool);

	function addGroupWithoutSetVotingEnd(address _addr) public;
}
