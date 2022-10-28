%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.access.ownable.library import Ownable

from openzeppelin.token.erc20.library import ERC20
from openzeppelin.introspection.erc165.library import ERC165


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    name: felt, symbol: felt, decimals: felt
){
    ERC20.initializer(name, symbol, decimals);
    // TODO : Ownable.initializer(owner);
    return ();
}

//GETTERS

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account: felt
) -> (
    balance : Uint256
){
    let (balance : Uint256) = ERC20.balance_of(account);
    return (balance=balance);
}

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    let (res : Uint256) = ERC20.allowance(owner, spender);
    return (remaining=res);
}

//EXTERNAL

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) {
    // todo : add ownable Ownable.assert_only_owner()
    ERC20._mint(recipient, amount);
    return ();
}


@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    account: felt, amount: Uint256
) {
    // todo : add ownable Ownable.assert_only_owner()
    ERC20._burn(account, amount);
    return ();
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) {
    ERC20.transfer_from(sender, recipient, amount);
    return();
}


@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
)-> (success : felt){
    let (res) = ERC20.approve(spender, amount);
    return (success=res);
}