%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC20 {

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }

    func mint(recipient: felt, amount: Uint256) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }
}