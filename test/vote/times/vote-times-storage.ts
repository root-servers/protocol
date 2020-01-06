import {DevProtocolInstance} from './../../lib/instance'
import {VoteTimesStorageInstance} from '../../../types/truffle-contracts'

contract(
	'VoteTimesStorageTest',
	([deployer, voteTimes, property, property2]) => {
		const dev = new DevProtocolInstance(deployer)
		before(async () => {
			await dev.generateAddressConfig()
			await dev.generateVoteTimesStorage()
			await dev.addressConfig.setVoteTimes(voteTimes, {from: deployer})
		})
		describe('VoteTimesStorage; getVoteTimes, setVoteTimes', () => {
			it('Initial value is 0.', async () => {
				const result = await dev.voteTimesStorage.getVoteTimes({
					from: voteTimes
				})
				expect(result.toNumber()).to.be.equal(0)
			})
			it('The set value can be taken as it is.', async () => {
				await dev.voteTimesStorage.setVoteTimes(3, {from: voteTimes})
				const result = await dev.voteTimesStorage.getVoteTimes({
					from: voteTimes
				})
				expect(result.toNumber()).to.be.equal(3)
			})
		})
		describe('VoteTimesStorage; getVoteTimesByProperty, setVoteTimesByProperty', () => {
			it('Initial value is 0.', async () => {
				const result = await dev.voteTimesStorage.getVoteTimesByProperty(
					property,
					{from: voteTimes}
				)
				expect(result.toNumber()).to.be.equal(0)
			})
			it('The set value can be taken as it is.', async () => {
				await dev.voteTimesStorage.setVoteTimesByProperty(property, 3, {
					from: voteTimes
				})
				const result = await dev.voteTimesStorage.getVoteTimesByProperty(
					property,
					{from: voteTimes}
				)
				expect(result.toNumber()).to.be.equal(3)
			})
			it('If not set, initial value can be taken.', async () => {
				const result = await dev.voteTimesStorage.getVoteTimesByProperty(
					property2,
					{from: voteTimes}
				)
				expect(result.toNumber()).to.be.equal(0)
			})
		})
		describe('VoteTimesStorage; getStorageAddress, setStorage, changeOwner', () => {
			it('Value is inherited.', async () => {
				const newVoteTimesStorage = await dev.generateInstance<
					VoteTimesStorageInstance
				>('VoteTimesStorage')
				const storageAddress = await dev.voteTimesStorage.getStorageAddress()
				await newVoteTimesStorage.setStorage(storageAddress, {from: deployer})
				await dev.voteTimesStorage.changeOwner(newVoteTimesStorage.address, {
					from: deployer
				})
				const result = await newVoteTimesStorage.getVoteTimesByProperty(
					property,
					{from: voteTimes}
				)
				expect(result.toNumber()).to.be.equal(3)
			})
		})
	}
)