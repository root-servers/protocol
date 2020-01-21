pragma solidity ^0.5.0;

import {ERC20} from "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
// prettier-ignore
import {ERC20Mintable} from "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import {SafeMath} from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import {Pausable} from "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import {Decimals} from "contracts/src/common/libs/Decimals.sol";
import {UsingValidator} from "contracts/src/common/validate/UsingValidator.sol";
import {Property} from "contracts/src/property/Property.sol";
import {PropertyGroup} from "contracts/src/property/PropertyGroup.sol";
import {UsingConfig} from "contracts/src/common/config/UsingConfig.sol";
import {LockupStorage} from "contracts/src/lockup/LockupStorage.sol";
import {Policy} from "contracts/src/policy/Policy.sol";

contract Lockup is Pausable, UsingConfig, UsingValidator {
	using SafeMath for uint256;
	using Decimals for uint256;

	// solium-disable-next-line no-empty-blocks
	constructor(address _config) public UsingConfig(_config) {}

	function lockup(address _from, address _property, uint256 _value) external {
		require(paused() == false, "You cannot use that");
		addressValidator().validateAddress(msg.sender, config().token());
		addressValidator().validateGroup(_property, config().propertyGroup());
		require(_value != 0, "illegal lockup value");

		bool isWaiting = getStorage().getWithdrawalStatus(_property, _from) !=
			0;
		require(isWaiting == false, "lockup is already canceled");
		addValue(_property, _from, _value);
		addPropertyValue(_property, _value);
		getStorage().setLastInterestPrice(
			_property,
			_from,
			getStorage().getInterestPrice(_property)
		);
		getStorage().setPendingInterestWithdrawal(
			_property,
			_from,
			calculateInterestAmount(_property, _from)
		);
	}

	function cancel(address _property) external {
		addressValidator().validateGroup(_property, config().propertyGroup());

		require(hasValue(_property, msg.sender), "dev token is not locked");
		bool isWaiting = getStorage().getWithdrawalStatus(
			_property,
			msg.sender
		) !=
			0;
		require(isWaiting == false, "lockup is already canceled");
		uint256 blockNumber = Policy(config().policy()).lockUpBlocks();
		blockNumber = blockNumber.add(block.number);
		getStorage().setWithdrawalStatus(_property, msg.sender, blockNumber);
	}

	function withdraw(address _property) external {
		addressValidator().validateGroup(_property, config().propertyGroup());

		require(possible(_property, msg.sender), "waiting for release");
		uint256 lockupedValue = getStorage().getValue(_property, msg.sender);
		require(lockupedValue == 0, "dev token is not locked");
		uint256 value = getStorage().getValue(_property, msg.sender);
		require(value != 0, "your token is 0");
		Property(_property).withdrawDev(msg.sender, value);
		withdrawInterest(_property);
		getStorage().setValue(_property, msg.sender, 0);
		subPropertyValue(_property, lockupedValue);
		getStorage().setWithdrawalStatus(_property, msg.sender, 0);
	}

	function increment(address _property, uint256 _interestResult) external {
		addressValidator().validateAddress(msg.sender, config().allocator());
		uint256 priceValue = _interestResult.outOf(
			getStorage().getPropertyValue(_property)
		);
		incrementInterest(_property, priceValue);
	}

	function calculateInterestAmount(address _property, address _user)
		private
		view
		returns (uint256)
	{
		uint256 _last = getStorage().getLastInterestPrice(_property, _user);
		uint256 price = getStorage().getInterestPrice(_property);
		uint256 priceGap = price - _last;
		uint256 lockupedValue = getStorage().getValue(_property, _user);
		uint256 value = priceGap * lockupedValue;
		return value.div(Decimals.basis());
	}

	function calculateWithdrawableInterestAmount(
		address _property,
		address _user
	) private view returns (uint256) {
		uint256 pending = getStorage().getPendingInterestWithdrawal(
			_property,
			_user
		);
		return calculateInterestAmount(_property, _user).add(pending);
	}

	function withdrawInterest(address _property) private {
		uint256 value = calculateWithdrawableInterestAmount(
			_property,
			msg.sender
		);
		getStorage().setPendingInterestWithdrawal(_property, msg.sender, 0);
		ERC20Mintable erc20 = ERC20Mintable(config().token());
		erc20.mint(msg.sender, value);
	}

	function getPropertyValue(address _property)
		external
		view
		returns (uint256)
	{
		return getStorage().getPropertyValue(_property);
	}

	function getValue(address _property, address _sender)
		external
		view
		returns (uint256)
	{
		return getStorage().getValue(_property, _sender);
	}

	function addValue(address _property, address _sender, uint256 _value)
		private
	{
		uint256 value = getStorage().getValue(_property, _sender);
		value = value.add(_value);
		getStorage().setValue(_property, _sender, value);
	}

	function hasValue(address _property, address _sender)
		private
		view
		returns (bool)
	{
		uint256 value = getStorage().getValue(_property, _sender);
		return value != 0;
	}

	function addPropertyValue(address _property, uint256 _value) private {
		uint256 value = getStorage().getPropertyValue(_property);
		value = value.add(_value);
		getStorage().setPropertyValue(_property, value);
	}

	function subPropertyValue(address _property, uint256 _value) private {
		uint256 value = getStorage().getPropertyValue(_property);
		value = value.sub(_value);
		getStorage().setPropertyValue(_property, value);
	}

	function incrementInterest(address _property, uint256 _priceValue) private {
		uint256 price = getStorage().getInterestPrice(_property);
		getStorage().setInterestPrice(_property, price.add(_priceValue));
	}

	function possible(address _property, address _from)
		private
		view
		returns (bool)
	{
		uint256 blockNumber = getStorage().getWithdrawalStatus(
			_property,
			_from
		);
		if (blockNumber == 0) {
			return false;
		}
		return blockNumber <= block.number;
	}

	function getStorage() private view returns (LockupStorage) {
		return LockupStorage(config().lockupStorage());
	}
}
