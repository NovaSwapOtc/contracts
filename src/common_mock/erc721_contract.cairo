%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.access.ownable.library import Ownable

from src.utils.token.erc1155.library import ERC
from openzeppelin.introspection.erc165.library import ERC165


@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
){
    ERC721.initializer();
    // TODO : Ownable.initializer(owner);
    return ();
}

//GETTERS

@view
func balanceOfBatch{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    accounts_len: felt, accounts: felt*, ids_len: felt, ids: Uint256*
) -> (batch_balances_len: felt, batch_balances: Uint256*){
    let (batch_balances_len: felt, batch_balances: Uint256*) = ERC1155.balance_of_batch(accounts_len,accounts,ids_len,ids);
    return (batch_balances_len=batch_balances_len,batch_balances=batch_balances);
}

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account: felt, id: Uint256
) -> (
    balance : Uint256
){
    let (balance : Uint256) = ERC1155.balance_of(account,id);
    return (balance=balance);
}

@view
func isApprovedForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt, operator : felt
) -> (isApproved : felt){
    let (isApproved : felt) = ERC1155.is_approved_for_all(account, operator);
    return (isApproved=isApproved);
}


//EXTERNAL

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt, id: Uint256, amount: Uint256, data_len: felt, data: felt*
) {
    // todo : add ownable Ownable.assert_only_owner()
    ERC1155._mint(to, id, amount, data_len, data);
    return ();
}

@external
func batchMint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt,
    ids_len: felt,
    ids: Uint256*,
    amounts_len: felt,
    amounts: Uint256*,
    data_len: felt,
    data: felt*,
) {
    // todo : add ownable Ownable.assert_only_owner()
    ERC1155._mint_batch(
        to,
        ids_len,
        ids,
        amounts_len,
        amounts,
        data_len,
        data,
    );
    return ();
}


@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, id: Uint256, amount: Uint256
) {
    // todo : add ownable Ownable.assert_only_owner()
    ERC1155._burn(from_, id, amount);
    return ();
}

@external
func batchBurn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, ids_len: felt, ids: Uint256*, amounts_len: felt, amounts: Uint256*
) {
    // todo : add ownable Ownable.assert_only_owner()
    ERC1155._burn_batch(from_, ids_len, ids, amounts_len, amounts);
    return ();
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, to: felt, id: Uint256, amount: Uint256, data_len: felt, data: felt*
) {
    ERC1155.safe_transfer_from(from_, to, id, amount, data_len, data);
    return();
}
@external
func batchTransferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt,
    to: felt,
    ids_len: felt,
    ids: Uint256*,
    amounts_len: felt,
    amounts: Uint256*,
    data_len: felt,
    data: felt*,
) {
    ERC1155.safe_batch_transfer_from(
        from_,
        to,
        ids_len,
        ids,
        amounts_len,
        amounts,
        data_len,
        data,
    );
    return ();
}


@external
func setApprovalForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt, approved : felt
){
    ERC1155.set_approval_for_all(account, approved);
    return ();
}